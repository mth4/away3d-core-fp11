package away3d.core.base
{
	import away3d.animators.data.AnimationBase;
	import away3d.arcane;
	import away3d.core.base.buffers.IndexBufferProxy;
	import away3d.core.base.buffers.VertexBufferProxy;
	import away3d.core.base.buffers.VertexBufferSelector;
	import away3d.core.base.buffers.VertexBufferUsages;
	import away3d.core.base.data.Vertex;
	import away3d.core.managers.Stage3DProxy;
	
	import flash.display3D.IndexBuffer3D;
	import flash.display3D.VertexBuffer3D;
	import flash.events.Event;
	import flash.geom.Matrix3D;
	import flash.geom.Vector3D;
	import flash.utils.Dictionary;

	use namespace arcane;

	/**
	 * The SubGeometry class is a collections of geometric data that describes a triangle mesh. It is owned by a
	 * Geometry instance, and wrapped by a SubMesh in the scene graph.
	 * Several SubGeometries are grouped so they can be rendered with different materials, but still represent a single
	 * object.
	 *
	 * @see away3d.core.base.Geometry
	 * @see away3d.core.base.SubMesh
	 */
	public class SubGeometry
	{
		private var _parentGeometry : Geometry;
		
		// raw data:
		protected var _faceNormalsData : Vector.<Number>;
		protected var _faceWeights : Vector.<Number>;
		protected var _faceTangents : Vector.<Number>;
		
		// buffers:
		protected var _selectors:Vector.<VertexBufferSelector> = new Vector.<VertexBufferSelector>();
		protected var _numSelectors:uint;
		
		protected var _positionsBuffer:VertexBufferProxy;
		protected var _normalsBuffer:VertexBufferProxy;
		protected var _tangentsBuffer:VertexBufferProxy;
		protected var _mainUVBuffer:VertexBufferProxy;
		protected var _indexBuffer:IndexBufferProxy;
		
		protected var _autoDeriveVertexNormals : Boolean = true;
		protected var _autoDeriveVertexTangents : Boolean = true;
		private var _useFaceWeights : Boolean = false;
		
		// raw data dirty flags:
		protected var _faceNormalsDirty : Boolean = true;
		protected var _faceTangentsDirty : Boolean = true;
		protected var _vertexNormalsDirty : Boolean = true;
		protected var _vertexTangentsDirty : Boolean = true;
		
		// already generated normal and tangent buffers (usage of weak keys ensures that it will not use any extra memory)
		static private var _vertexNormalsMapping:StructuredMapping;	// position buffer -> index buffer -> useFaceWeights -> BUFFER
		static private var _vertexTangentsMapping:StructuredMapping;	// position buffer -> index buffer -> main uv buffer -> BUFFER
		
		/*
		* PUBLIC
		*/
		public function SubGeometry()
		{
			if(_vertexNormalsMapping == null) _vertexNormalsMapping = new StructuredMapping();
			if(_vertexTangentsMapping == null) _vertexTangentsMapping = new StructuredMapping();
		}
		
		/**
		 * The animation that affects the geometry.
		 */
		public function get animation() : AnimationBase
		{
			return _parentGeometry._animation;
		}
		
		/**
		 * The total amount of vertices in the SubGeometry.
		 */
		public function get numVertices() : uint
		{
			return _positionsBuffer != null ? _positionsBuffer.numVertices : 0;
		}
		
		/**
		 * The total amount of triangles in the SubGeometry.
		 */
		public function get numTriangles() : uint
		{
			return _indexBuffer != null ? _indexBuffer.numTriangles : 0;
		}
		
		/**
		 * True if the vertex normals should be derived from the geometry, false if the vertex normals are set
		 * explicitly.
		 */
		public function get autoDeriveVertexNormals() : Boolean
		{
			return _autoDeriveVertexNormals;
		}
		
		public function set autoDeriveVertexNormals(value : Boolean) : void
		{
			_autoDeriveVertexNormals = value;
			
			_vertexNormalsDirty = value;
		}
		
		/**
		 * True if the vertex tangents should be derived from the geometry, false if the vertex normals are set
		 * explicitly.
		 */
		public function get autoDeriveVertexTangents() : Boolean
		{
			return _autoDeriveVertexTangents;
		}
		
		public function set autoDeriveVertexTangents(value : Boolean) : void
		{
			_autoDeriveVertexTangents = value;
			
			_vertexTangentsDirty = value;
		}
		
		/**
		 * Indicates whether or not to take the size of faces into account when auto-deriving vertex normals and tangents.
		 */
		public function get useFaceWeights() : Boolean
		{
			return _useFaceWeights;
		}
		
		public function set useFaceWeights(value : Boolean) : void
		{
			_useFaceWeights = value;
			if (_autoDeriveVertexNormals) _vertexNormalsDirty = true;
			if (_autoDeriveVertexTangents) _vertexTangentsDirty = true;
			_faceNormalsDirty = true;
		}
		
		/**
		 * Adds vertex buffer selector to this SubGeometry instance.
		 */
		public function addVertexBufferSelector(selector:VertexBufferSelector):void
		{
			var buffer:VertexBufferProxy = selector.bufferProxy;
			
			switch(selector.usage)
			{
				case VertexBufferUsages.POSITIONS:
					if(buffer.selectors.length != 1)
						throw new Error("Multiple selectors for position buffer is currently not allowed");
					
					if(_positionsBuffer == null)
					{
						_positionsBuffer = buffer;
						_positionsBuffer.addEventListener(Event.CHANGE, onPositionsBufferChange);
					}
					break;
				
				case VertexBufferUsages.NORMALS:
					if(buffer.selectors.length != 1)
						throw new Error("Multiple selectors for normal buffer is currently not allowed");
					
					_normalsBuffer = buffer;
					break;
				
				case VertexBufferUsages.TANGENTS:
					if(buffer.selectors.length != 1)
						throw new Error("Multiple selectors for tangents buffer is currently not allowed");
					
					_tangentsBuffer = buffer;
					break;
				
				case VertexBufferUsages.UV:
					if(_mainUVBuffer == null)
					{
						if(buffer.selectors.length == 1)		// it is ok for UV's in general, but this class doesn't support it for main UVs to maintain backward compatibility
						{
							_mainUVBuffer = buffer;
							_mainUVBuffer.addEventListener(Event.CHANGE, onUVBufferChange);
						}
					}
					break;
			}
			
			_numSelectors++;
			buffer.addOwner(this);		// may add ownership multiple times (for each selector) for one buffer
			_selectors.push(selector);
		}
		
		public function removeVertexBufferSelector(selector:VertexBufferSelector):void
		{
			var buffer:VertexBufferProxy = selector.bufferProxy;
			var numSelectors:uint = _selectors.length;
			
			for(var i:uint=0; i<numSelectors; ++i)
				if(_selectors[i] == selector)
				{
					_selectors.splice(i, 1);
					
					if(_positionsBuffer == buffer)
					{
						_positionsBuffer.removeEventListener(Event.CHANGE, onPositionsBufferChange);
						_positionsBuffer = null;
					}
					
					if(_mainUVBuffer == buffer)
					{
						_mainUVBuffer.removeEventListener(Event.CHANGE, onUVBufferChange);
						_mainUVBuffer = null;
					}
					
					if(_normalsBuffer == buffer) _normalsBuffer = null;
					if(_tangentsBuffer == buffer) _tangentsBuffer = null;
					
					_numSelectors--;
					buffer.removeOwner(this);
					
					return;
				}
		}
		
		/**
		 * Adds all of buffer's selectors to this SubGeometry instance.
		 */
		public function addVertexBuffer(buffer:VertexBufferProxy):void
		{
			for each(var selector:VertexBufferSelector in buffer.selectors)
				addVertexBufferSelector(selector);
		}
		
		/**
		 * Removes all of buffer's selectors from this SubGeometry instance.
		 */
		public function removeVertexBuffer(buffer:VertexBufferProxy):void
		{
			for each(var selector:VertexBufferSelector in buffer.selectors)
				removeVertexBufferSelector(selector);
		}
		
		public function get positionsProxy():VertexBufferProxy
		{
			return _positionsBuffer;
		}
		
		public function get mainUVProxy():VertexBufferProxy
		{
			return _mainUVBuffer;
		}
		
		public function get normalsProxy():VertexBufferProxy
		{
			if(_autoDeriveVertexNormals && _vertexNormalsDirty)
				updateVertexNormals();
			
			return _normalsBuffer;
		}
		
		public function get tangentsProxy():VertexBufferProxy
		{
			if(_vertexTangentsDirty)
				updateVertexTangents();
			
			return _tangentsBuffer;
		}
		
		public function get indexBufferProxy():IndexBufferProxy
		{
			return _indexBuffer;
		}
		
		public function set indexBufferProxy(buffer:IndexBufferProxy):void
		{
			if(_indexBuffer == buffer)
				return;
			
			if(_indexBuffer != null)
				_indexBuffer.removeEventListener(Event.CHANGE, onIndexBufferChange);
			
			_indexBuffer = buffer;
			_indexBuffer.addOwner(this);
			_indexBuffer.addEventListener(Event.CHANGE, onIndexBufferChange);
			
			onIndexBufferChange(null);
		}
		
		/**
		 * Retrieves vertex buffer selector with given usage.
		 * @param usage One of VertexBufferUsages class constants or some custom usage.
		 * @param index Index of selector, if multiple selectors with this usage are expected.
		 * @todo It will be faster to store selectors in dictionary where usages would be keys and values would be vectors with selectors.
		 */
		public function getVertexBufferSelector(usage:String, index:uint=0):VertexBufferSelector
		{
			for each(var selector:VertexBufferSelector in _selectors)
				if(selector.usage == usage)
				{
					if(index == 0)
						return selector;
					index--;
				}
			
			// if not found, in some cases it should be automatically generated (getters below do the job)
			switch(usage)
			{
				case VertexBufferUsages.NORMALS: return normalsProxy.selectors[0];
				case VertexBufferUsages.TANGENTS: return tangentsProxy.selectors[0];
			}
			
			return null;
		}
		
		public function getVertexBufferSelectorAt(index:uint):VertexBufferSelector
		{
			return _selectors[index];
		}
		
		public function get numSelectors():uint
		{
			return _numSelectors;
		}
		
		public function getReferencedVertexBuffers():Vector.<VertexBufferProxy>
		{
			var vec:Vector.<VertexBufferProxy> = new Vector.<VertexBufferProxy>();
			
			for each(var selector:VertexBufferSelector in _selectors)
			{
				var buffer:VertexBufferProxy = selector.bufferProxy;
				if(vec.indexOf(buffer) == -1)
					vec.push(buffer);
			}
			
			return vec;
		}
		
		/**
		 * Retrieves uv buffer selector at specified index.
		 */
		public function getUVBufferSelector(index:uint):VertexBufferSelector
		{
			return getVertexBufferSelector(VertexBufferUsages.UV, index);
		}
		
		/**
		 * Retrieves the VertexBuffer3D object that contains vertex positions.
		 * @param context The Context3D for which we request the buffer
		 * @return The VertexBuffer3D object that contains vertex positions.
		 */
		[Deprecated(replacement="getVertexBufferSelector(...) or positionsBufferProxy.getBuffer(...)")]
		public function getVertexBuffer(stage3DProxy:Stage3DProxy):VertexBuffer3D
		{
			return _positionsBuffer.getBuffer(stage3DProxy);
		}
		
		/**
		 * Retrieves the VertexBuffer3D object that contains texture coordinates.
		 * @param context The Context3D for which we request the buffer
		 * @return The VertexBuffer3D object that contains texture coordinates.
		 */
		[Deprecated(replacement="getVertexBufferSelector(...) or mainUVBufferProxy.getBuffer(...)")]
		public function getUVBuffer(stage3DProxy:Stage3DProxy):VertexBuffer3D
		{
			return _mainUVBuffer.getBuffer(stage3DProxy);
		}
		
		public function applyTransformation(transform:Matrix3D):void
		{
			var positions:Vector.<Number> = _positionsBuffer.data;
			var vertexNormals:Vector.<Number> = _normalsBuffer != null ? _normalsBuffer.data : null;
			var vertexTangents:Vector.<Number> = _tangentsBuffer != null ? _tangentsBuffer.data : null;
			
			var len : uint = positions.length/3;
			var i:uint, i0:uint, i1:uint, i2:uint;
			var v3:Vector3D = new Vector3D();
			
			var bakeNormals:Boolean = vertexNormals != null;
			var bakeTangents:Boolean = vertexTangents != null;
			
			for (i = 0; i < len; ++i) {
				
				i0 = 3 * i;
				i1 = i0 + 1;
				i2 = i0 + 2;
				
				// bake position
				v3.x = positions[i0];
				v3.y = positions[i1];
				v3.z = positions[i2];
				v3 = transform.transformVector(v3);
				positions[i0] = v3.x;
				positions[i1] = v3.y;
				positions[i2] = v3.z;
				
				// bake normal
				if(bakeNormals)
				{
					v3.x = vertexNormals[i0];
					v3.y = vertexNormals[i1];
					v3.z = vertexNormals[i2];
					v3 = transform.deltaTransformVector(v3);
					vertexNormals[i0] = v3.x;
					vertexNormals[i1] = v3.y;
					vertexNormals[i2] = v3.z;
				}
				
				// bake tangent
				if(bakeTangents)
				{
					v3.x = vertexTangents[i0];
					v3.y = vertexTangents[i1];
					v3.z = vertexTangents[i2];
					v3 = transform.deltaTransformVector(v3);
					vertexTangents[i0] = v3.x;
					vertexTangents[i1] = v3.y;
					vertexTangents[i2] = v3.z;
				}
			}
			
			_positionsBuffer.invalidateContent();
			if(_normalsBuffer != null) _normalsBuffer.invalidateContent();
			if(_tangentsBuffer != null) _tangentsBuffer.invalidateContent();
		}
		
		[Deprecated(replacement="getVertexBufferSelector(...)")]
		public function getSecondaryUVBuffer(stage3DProxy : Stage3DProxy) : VertexBuffer3D
		{
			return getVertexBufferSelector(VertexBufferUsages.UV, 1).bufferProxy.getBuffer(stage3DProxy);
		}
		
		/**
		 * Retrieves the VertexBuffer3D object that contains vertex normals.
		 * @param context The Context3D for which we request the buffer
		 * @return The VertexBuffer3D object that contains vertex normals.
		 */
		[Deprecated(replacement="getVertexBufferSelector(...) or normalsBufferProxy.getBuffer(...)")]
		public function getVertexNormalBuffer(stage3DProxy:Stage3DProxy):VertexBuffer3D
		{
			return normalsProxy.getBuffer(stage3DProxy);
		}
		
		/**
		 * Retrieves the VertexBuffer3D object that contains vertex tangents.
		 * @param context The Context3D for which we request the buffer
		 * @return The VertexBuffer3D object that contains vertex tangents.
		 */
		[Deprecated(replacement="getVertexBufferSelector(...) or tangentsBufferProxy.getBuffer(...)")]
		public function getVertexTangentBuffer(stage3DProxy:Stage3DProxy):VertexBuffer3D
		{
			return tangentsProxy.getBuffer(stage3DProxy);
		}
		
		/**
		 * Retrieves the VertexBuffer3D object that contains triangle indices.
		 * @param context The Context3D for which we request the buffer
		 * @return The VertexBuffer3D object that contains triangle indices.
		 */
		[Deprecated(replacement="indexBufferProxy")]
		public function getIndexBuffer(stage3DProxy : Stage3DProxy) : IndexBuffer3D
		{
			return _indexBuffer.getBuffer(stage3DProxy);
		}
		
		/**
		 * Clones the current object
		 * @return An exact duplicate of the current object.
		 */
		public function clone(cloneBuffers:Boolean=false) : SubGeometry
		{
			var selector:VertexBufferSelector;
			
			var clone:SubGeometry = new SubGeometry();
			
			if(!cloneBuffers)
			{
				for each(selector in _selectors)
					clone.addVertexBufferSelector(selector);
			}
			else
			{
				var buffersClones:Dictionary = new Dictionary();
				for each(selector in _selectors)			// clone buffers referenced by selectors
					if(buffersClones[selector.bufferProxy] == null)
						buffersClones[selector.bufferProxy.clone()];
				
				for each(selector in _selectors)			// find correct selectors in cloned buffers
					for each(var selector2:VertexBufferSelector in selector.bufferProxy.selectors)
						if(selector.usage == selector2.usage && selector.offset == selector2.offset)
							clone.addVertexBufferSelector(selector2);
			}
			
			clone._indexBuffer = cloneBuffers ? _indexBuffer.clone() : _indexBuffer;
			
			return clone;
		}
		
		/**
		 * Clears all resources used by the SubGeometry object.
		 */
		public function dispose() : void
		{
			for each(var selector:VertexBufferSelector in _selectors)
				selector.bufferProxy.removeOwner(this);
			
			if(_indexBuffer != null)
				_indexBuffer.removeOwner(this);
			
			_selectors = null;
			
			_positionsBuffer = null;
			_normalsBuffer = null;
			_tangentsBuffer = null;
			_mainUVBuffer = null;
			_indexBuffer = null;
			
			_faceNormalsData = null;
			_faceWeights = null;
			_faceTangents = null;
		}
		
		/**
		 * The raw vertex position data.
		 */
		public function get vertexData() : Vector.<Number>
		{
			return _positionsBuffer != null ? _positionsBuffer.data : null;
		}
		
		/**
		 * The raw texture coordinate data.
		 */
		public function get UVData() : Vector.<Number>
		{
			return _mainUVBuffer != null ? _mainUVBuffer.data : null;
		}
		
		/**
		 * The raw texture coordinate data. Will not work correctly if uv buffer is ComplexVertexBufferProxy.
		 */
		[Deprecated(replacement="getVertexBufferSelector(UV, 1).bufferData")]
		public function get secondaryUVData() : Vector.<Number>
		{
			var buff:VertexBufferSelector = getUVBufferSelector(1);
			return buff != null ? buff.bufferProxy.data : null;
		}
		
		/**
		 * The raw vertex normal data.
		 */
		public function get vertexNormalData() : Vector.<Number>
		{
			if (_autoDeriveVertexNormals && _vertexNormalsDirty) updateVertexNormals();
			return _normalsBuffer != null ? _normalsBuffer.data : null;
		}
		
		/**
		 * The raw vertex tangent data.
		 *
		 * @private
		 */
		public function get vertexTangentData() : Vector.<Number>
		{
			if (_autoDeriveVertexTangents && _vertexTangentsDirty) updateVertexTangents();
			return _tangentsBuffer != null ? _tangentsBuffer.data : null;
		}
		
		/**
		 * The raw index data that define the faces.
		 *
		 * @private
		 */
		public function get indexData() : Vector.<uint>
		{
			return _indexBuffer != null ? _indexBuffer.indices : null;
		}
		
		/**
		 * Updates the vertex data of the SubGeometry.
		 * @param vertices The new vertex data to upload.
		 */
		public function updateVertexData(vertices : Vector.<Number>) : void
		{
			if(_positionsBuffer == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.POSITIONS, vertices, 3));
			else
			{
				_positionsBuffer.data = vertices;
				_positionsBuffer.invalidateContent();		// that method should invalidate content, even if it is the same vector
			}
		}
		
		/**
		 * Updates the uv coordinates of the SubGeometry.
		 * @param uvs The uv coordinates to upload.
		 */
		public function updateUVData(uvs:Vector.<Number>):void
		{
			if(_mainUVBuffer == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.UV, uvs, 2));
			else
			{
				_mainUVBuffer.data = uvs;
				_mainUVBuffer.invalidateContent();
			}
		}
		
		/**
		 * @deprecated
		 */
		public function updateSecondaryUVData(uvs : Vector.<Number>) : void
		{
			var selector:VertexBufferSelector = getVertexBufferSelector(VertexBufferUsages.UV, 1);
			if(selector == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.UV, uvs, 2));
			else
			{
				selector.bufferProxy.data = uvs;
				selector.bufferProxy.invalidateContent();
			}
		}
		
		/**
		 * Updates the vertex normals of the SubGeometry. When updating the vertex normals like this,
		 * autoDeriveVertexNormals will be set to false and vertex normals will no longer be calculated automatically.
		 * @param vertexNormals The vertex normals to upload.
		 */
		public function updateVertexNormalData(vertexNormals:Vector.<Number>):void
		{
			_vertexNormalsDirty = false;
			_autoDeriveVertexNormals = (vertexNormals == null);
			
			if(_normalsBuffer == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.NORMALS, vertexNormals, 3));
			else
			{
				_normalsBuffer.data = vertexNormals;
				_normalsBuffer.invalidateContent();
			}
		}
		
		/**
		 * Updates the vertex tangents of the SubGeometry. When updating the vertex tangents like this,
		 * autoDeriveVertexTangents will be set to false and vertex tangents will no longer be calculated automatically.
		 * @param vertexTangents The vertex tangents to upload.
		 */
		public function updateVertexTangentData(vertexTangents:Vector.<Number>):void
		{
			_vertexTangentsDirty = false;
			_autoDeriveVertexTangents = (vertexTangents == null);
			
			if(_tangentsBuffer == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.TANGENTS, vertexTangents, 3));
			else
			{
				_tangentsBuffer.data = vertexTangents;
				_tangentsBuffer.invalidateContent();
			}
		}
		
		/**
		 * Updates the face indices of the SubGeometry.
		 * @param indices The face indices to upload.
		 */
		public function updateIndexData(indices : Vector.<uint>) : void
		{
			if(_indexBuffer == null)
				indexBufferProxy = new IndexBufferProxy(indices);
			else
			{
				_indexBuffer.indices = indices;
				_indexBuffer.invalidateContent();
			}
		}
		
		/**
		 * The raw data of the face normals, in the same order as the faces are listed in the index list.
		 *
		 * @private
		 */
		arcane function get faceNormalsData() : Vector.<Number>
		{
			if (_faceNormalsDirty) updateFaceNormals();
			return _faceNormalsData;
		}
		
		/**
		 * The Geometry object that 'owns' this SubGeometry object.
		 *
		 * @private
		 */
		arcane function get parentGeometry() : Geometry
		{
			return _parentGeometry;
		}
		
		arcane function set parentGeometry(value : Geometry) : void
		{
			_parentGeometry = value;
		}
		
		public function get vertexBufferOffset() : int
		{
			return 0;
		}
		
		public function get normalBufferOffset() : int
		{
			return 0;
		}
		
		public function get tangentBufferOffset() : int
		{
			return 0;
		}
		
		public function get UVBufferOffset() : int
		{
			return 0;
		}
		
		public function get secondaryUVBufferOffset() : int
		{
			return 0;
		}
		
		/*
		* PROTECTED
		*/
		protected function disposeForStage3D(stage3DProxy : Stage3DProxy) : void
		{
			var index:int = stage3DProxy._stage3DIndex;
			
			for each(var selector:VertexBufferSelector in _selectors)
				selector.bufferProxy.disposeForStage3D(stage3DProxy);
			
			if(_indexBuffer != null)
				_indexBuffer.disposeForStage3D(stage3DProxy);
		}
		
		/*
		* PRIVATE
		*/
		private function invalidateBounds() : void
		{
			if (_parentGeometry) _parentGeometry.invalidateBounds(this);
		}
		
		private function updateVertexNormals() : void
		{
			var buffer:VertexBufferProxy = _vertexNormalsMapping.getObject([_positionsBuffer, _indexBuffer, _useFaceWeights]) as VertexBufferProxy;
			if(buffer != null)
			{
				if(_normalsBuffer != null)
					removeVertexBuffer(_normalsBuffer);
				
				addVertexBuffer(buffer);
				return;
			}
			
			if (_faceNormalsDirty)
				updateFaceNormals();
			
			var positions:Vector.<Number> = _positionsBuffer.data;
			var indices:Vector.<uint> = _indexBuffer.indices;
			
			var v1 : uint, v2 : uint, v3 : uint;
			var f1 : uint = 0, f2 : uint = 1, f3 : uint = 2;
			var lenV : uint = positions.length;
			
			var vertexNormals:Vector.<Number>;
			
			if(_normalsBuffer)
			{
				_normalsBuffer.clear();
				vertexNormals = _normalsBuffer.data;
			}
			else
				vertexNormals = new Vector.<Number>(lenV, true);
			
			var i : uint, k : uint;
			var lenI : uint = indices.length;
			var index : uint;
			var weight : uint;
			
			while (i < lenI) {
				weight = _useFaceWeights? _faceWeights[k++] : 1;
				index = indices[i++]*3;
				vertexNormals[index++] += _faceNormalsData[f1]*weight;
				vertexNormals[index++] += _faceNormalsData[f2]*weight;
				vertexNormals[index] += _faceNormalsData[f3]*weight;
				index = indices[i++]*3;
				vertexNormals[index++] += _faceNormalsData[f1]*weight;
				vertexNormals[index++] += _faceNormalsData[f2]*weight;
				vertexNormals[index] += _faceNormalsData[f3]*weight;
				index = indices[i++]*3;
				vertexNormals[index++] += _faceNormalsData[f1]*weight;
				vertexNormals[index++] += _faceNormalsData[f2]*weight;
				vertexNormals[index] += _faceNormalsData[f3]*weight;
				f1 += 3;
				f2 += 3;
				f3 += 3;
			}
			
			v1 = 0; v2 = 1; v3 = 2;
			while (v1 < lenV) {
				var vx : Number = vertexNormals[v1];
				var vy : Number = vertexNormals[v2];
				var vz : Number = vertexNormals[v3];
				var d : Number = 1.0/Math.sqrt(vx*vx+vy*vy+vz*vz);
				vertexNormals[v1] *= d;
				vertexNormals[v2] *= d;
				vertexNormals[v3] *= d;
				v1 += 3;
				v2 += 3;
				v3 += 3;
			}
			
			_vertexNormalsDirty = false;
			
			if(_normalsBuffer != null)
				_normalsBuffer.invalidateContent();
			else
				_normalsBuffer = new VertexBufferProxy(VertexBufferUsages.NORMALS, vertexNormals, 3);
			
			_vertexNormalsMapping.saveObject(_normalsBuffer, [_positionsBuffer, _indexBuffer, _useFaceWeights]);
		}
		
		/**
		 * Updates the vertex tangents based on the geometry.
		 */
		private function updateVertexTangents() : void
		{
			var buffer:VertexBufferProxy = _vertexTangentsMapping.getObject([_positionsBuffer, _indexBuffer, _mainUVBuffer]) as VertexBufferProxy;
			if(buffer != null)
			{
				if(_tangentsBuffer != null)
					removeVertexBuffer(_tangentsBuffer);
				
				addVertexBuffer(buffer);
				return;
			}
			
			if (_vertexNormalsDirty)
				updateVertexNormals();
			
			if (_faceTangentsDirty)
				updateFaceTangents();
			
			var positions:Vector.<Number> = _positionsBuffer.data;
			var indices:Vector.<uint> = _indexBuffer.indices;
			var numIndices:uint = _indexBuffer.numIndices;
			
			var v1 : uint, v2 : uint, v3 : uint;
			var f1 : uint = 0, f2 : uint = 1, f3 : uint = 2;
			var lenV : uint = positions.length;
			
			var vertexTangents:Vector.<Number>;
			
			if(_tangentsBuffer)
			{
				_tangentsBuffer.clear();
				vertexTangents = _tangentsBuffer.data;
			}
			else
				vertexTangents = new Vector.<Number>(lenV, true);
			
			var i : uint, k : uint;
			var lenI : uint = numIndices;
			var index : uint;
			var weight : uint;
			
			while (i < lenI) {
				weight = _useFaceWeights? _faceWeights[k++] : 1;
				index = indices[i++]*3;
				vertexTangents[index++] += _faceTangents[f1]*weight;
				vertexTangents[index++] += _faceTangents[f2]*weight;
				vertexTangents[index] += _faceTangents[f3]*weight;
				index = indices[i++]*3;
				vertexTangents[index++] += _faceTangents[f1]*weight;
				vertexTangents[index++] += _faceTangents[f2]*weight;
				vertexTangents[index] += _faceTangents[f3]*weight;
				index = indices[i++]*3;
				vertexTangents[index++] += _faceTangents[f1]*weight;
				vertexTangents[index++] += _faceTangents[f2]*weight;
				vertexTangents[index] += _faceTangents[f3]*weight;
				f1 += 3;
				f2 += 3;
				f3 += 3;
			}
			
			v1 = 0; v2 = 1; v3 = 2;
			while (v1 < lenV) {
				var vx : Number = vertexTangents[v1];
				var vy : Number = vertexTangents[v2];
				var vz : Number = vertexTangents[v3];
				var d : Number = 1.0/Math.sqrt(vx*vx+vy*vy+vz*vz);
				vertexTangents[v1] *= d;
				vertexTangents[v2] *= d;
				vertexTangents[v3] *= d;
				v1 += 3;
				v2 += 3;
				v3 += 3;
			}
			
			_vertexTangentsDirty = false;
			
			if(_tangentsBuffer != null)
				_tangentsBuffer.invalidateContent();
			else
				_tangentsBuffer = new VertexBufferProxy(VertexBufferUsages.TANGENTS, vertexTangents, 3);
			
			_vertexTangentsMapping.saveObject(_tangentsBuffer, [_positionsBuffer, _indexBuffer, _mainUVBuffer]);
		}
		
		private function updateFaceNormals() : void
		{
			var positions:Vector.<Number> = _positionsBuffer.data;
			var indices:Vector.<uint> = _indexBuffer.indices;
			var numIndices:uint = _indexBuffer.numIndices;
			
			var i : uint, j : uint, k : uint;
			var index : uint;
			var x1 : Number, x2 : Number, x3 : Number;
			var y1 : Number, y2 : Number, y3 : Number;
			var z1 : Number, z2 : Number, z3 : Number;
			var dx1 : Number, dy1 : Number, dz1 : Number;
			var dx2 : Number, dy2 : Number, dz2 : Number;
			var cx : Number, cy : Number, cz : Number;
			var d : Number;
			
			_faceNormalsData ||= new Vector.<Number>(numIndices, true);
			if (_useFaceWeights) _faceWeights ||= new Vector.<Number>(numTriangles, true);
			
			while (i < numIndices) {
				index = indices[i++]*3;
				x1 = positions[index++];
				y1 = positions[index++];
				z1 = positions[index];
				index = indices[i++]*3;
				x2 = positions[index++];
				y2 = positions[index++];
				z2 = positions[index];
				index = indices[i++]*3;
				x3 = positions[index++];
				y3 = positions[index++];
				z3 = positions[index];
				dx1 = x3-x1;
				dy1 = y3-y1;
				dz1 = z3-z1;
				dx2 = x2-x1;
				dy2 = y2-y1;
				dz2 = z2-z1;
				cx = dz1*dy2 - dy1*dz2;
				cy = dx1*dz2 - dz1*dx2;
				cz = dy1*dx2 - dx1*dy2;
				d = Math.sqrt(cx*cx+cy*cy+cz*cz);
				// length of cross product = 2*triangle area
				if (_useFaceWeights) {
					var w : Number = d*10000;
					if (w < 1) w = 1;
					_faceWeights[k++] = w;
				}
				d = 1/d;
				_faceNormalsData[j++] = cx*d;
				_faceNormalsData[j++] = cy*d;
				_faceNormalsData[j++] = cz*d;
			}
			
			_faceNormalsDirty = false;
			_faceTangentsDirty = true;
		}
		
		/**
		 * Updates the tangents for each face.
		 */
		private function updateFaceTangents() : void
		{
			var positions:Vector.<Number> = _positionsBuffer.data;
			var uvs:Vector.<Number> = _mainUVBuffer.data;
			var indices:Vector.<uint> = _indexBuffer.indices;
			var numIndices:uint = _indexBuffer.numIndices;
			
			var i : uint, j : uint;
			var index1 : uint, index2 : uint, index3 : uint;
			var ui : uint, vi : uint;
			var v0 : Number;
			var dv1 : Number, dv2 : Number;
			var denom : Number;
			var x0 : Number, y0 : Number, z0 : Number;
			var dx1 : Number, dy1 : Number, dz1 : Number;
			var dx2 : Number, dy2 : Number, dz2 : Number;
			var cx : Number, cy : Number, cz : Number;
			
			_faceTangents ||= new Vector.<Number>(numIndices, true);
			
			while (i < numIndices) {
				index1 = indices[i++];
				index2 = indices[i++];
				index3 = indices[i++];
				
				v0 = uvs[uint((index1 << 1) + 1)];
				ui = index2 << 1;
				dv1 = (uvs[uint((index2 << 1) + 1)] - v0);
				ui = index3 << 1;
				dv2 = (uvs[uint((index3 << 1) + 1)] - v0);
				
				vi = index1*3;
				x0 = positions[vi];
				y0 = positions[uint(vi+1)];
				z0 = positions[uint(vi+2)];
				vi = index2*3;
				dx1 = positions[uint(vi)] - x0;
				dy1 = positions[uint(vi+1)] - y0;
				dz1 = positions[uint(vi+2)] - z0;
				vi = index3*3;
				dx2 = positions[uint(vi)] - x0;
				dy2 = positions[uint(vi+1)] - y0;
				dz2 = positions[uint(vi+2)] - z0;
				
				cx = dv2*dx1 - dv1*dx2;
				cy = dv2*dy1 - dv1*dy2;
				cz = dv2*dz1 - dv1*dz2;
				denom = 1/Math.sqrt(cx*cx + cy*cy + cz*cz);
				_faceTangents[j++] = denom*cx;
				_faceTangents[j++] = denom*cy;
				_faceTangents[j++] = denom*cz;
			}
			
			_faceTangentsDirty = false;
		}
		
		/*
		* PRIVATE - EVENTS
		*/
		private function onPositionsBufferChange(event:Event):void
		{
			// second checks ensure that the data change affected the static data (per-frame dataVariation updates doesn't force any update)
			if(_autoDeriveVertexNormals && (_normalsBuffer == null || _normalsBuffer.dataVariation == null)) _vertexNormalsDirty = true;
			if(_autoDeriveVertexTangents && (_tangentsBuffer == null || _tangentsBuffer.dataVariation == null)) _vertexTangentsDirty = true;
			
			_faceNormalsDirty = true;
			
			_vertexTangentsMapping.removeObject([_positionsBuffer, _indexBuffer, _mainUVBuffer]);
		}
		
		private function onUVBufferChange(event:Event):void
		{
			if (_autoDeriveVertexTangents) _vertexTangentsDirty = true;
			_faceTangentsDirty = true;
			
			_vertexTangentsMapping.removeObject([_positionsBuffer, _indexBuffer, _mainUVBuffer]);
		}
		
		private function onIndexBufferChange(event:Event):void
		{
			_faceNormalsDirty = true;
			
			if (_autoDeriveVertexNormals) _vertexNormalsDirty = true;
			if (_autoDeriveVertexTangents) _vertexTangentsDirty = true;
		}
	}
}

import flash.utils.Dictionary;

class StructuredMapping
{
	private var _dictionary:Dictionary = new Dictionary(true);
	
	public function getObject(keys:Array):Object
	{
		var current:Object = _dictionary;
		for each(var key:Object in keys)
		{
			current = current[key];
			if(current == null)
				return null;
		}
		
		return current;
	}
	
	public function saveObject(object:Object, keys:Array):void
	{
		var lastKey:Object = keys.splice(keys.length-1, 1)[0];
		var current:Object = _dictionary;
		
		for each(var key:Object in keys)
		current = (current[key] ||= new Dictionary(true));
		
		current[lastKey] = object;
	}
	
	public function removeObject(keys:Array):void
	{
		var lastKey:Object = keys.splice(keys.length-1, 1)[0];
		var current:Object = _dictionary;
		
		for each(var key:Object in keys)
		{
			current = current[key];
			if(current == null)
				return;
		}
		
		delete current[lastKey];
	}
}