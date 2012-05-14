package away3d.core.base
{
	import away3d.arcane;
	import away3d.core.base.buffers.VertexBufferProxy;
	import away3d.core.base.buffers.VertexBufferSelector;
	import away3d.core.base.buffers.VertexBufferUsages;
	import away3d.core.managers.Stage3DProxy;
	
	import flash.display3D.VertexBuffer3D;
	import flash.events.Event;
	import flash.utils.Dictionary;

	use namespace arcane;

	/**
	 * SkinnedSubGeometry provides a SubGeometry extension that contains data needed to skin vertices. In particular,
	 * it provides joint indices and weights.
	 * Important! Joint indices need to be pre-multiplied by 3, since they index the matrix array (and each matrix has 3 float4 elements)
	 */
	public class SkinnedSubGeometry extends SubGeometry
	{
		private var _jointWeightsProxy : VertexBufferProxy;
		private var _jointIndexProxy : VertexBufferProxy;

		private var _jointsPerVertex : int;

		private var _condensedIndexLookUp : Vector.<uint>;	// used for linking condensed indices to the real ones
		private var _numCondensedJoints : uint;


		/**
		 * Creates a new SkinnedSubGeometry object.
		 * @param jointsPerVertex The amount of joints that can be assigned per vertex.
		 */
		public function SkinnedSubGeometry(jointsPerVertex : int)
		{
			super();
			_jointsPerVertex = jointsPerVertex;
		}
		
		override public function addVertexBufferSelector(selector:VertexBufferSelector):void
		{
			super.addVertexBufferSelector(selector);
			
			var buffer:VertexBufferProxy = selector.bufferProxy;
			
			switch(selector.usage)
			{
				case VertexBufferUsages.POSITIONS:
					animatedVertexData = new Vector.<Number>(buffer.length);
					buffer.addEventListener(Event.CHANGE, onPositionsChange);
					break;
				
				case VertexBufferUsages.NORMALS:
					animatedNormalData = new Vector.<Number>(buffer.length);
					buffer.addEventListener(Event.CHANGE, onNormalsChange);
					break;
				
				case VertexBufferUsages.TANGENTS:
					animatedTangentData = new Vector.<Number>(buffer.length);
					buffer.addEventListener(Event.CHANGE, onTangentsChange);
					break;
				
				case VertexBufferUsages.JOINT_INDICES:
					_jointIndexProxy = buffer;
					break;
				
				case VertexBufferUsages.JOINT_WEIGHTS:
					_jointWeightsProxy = buffer;
					break;
			}
		}
		
		override public function removeVertexBufferSelector(selector:VertexBufferSelector):void
		{
			var buffer:VertexBufferProxy = selector.bufferProxy;
			
			if(_positionsBuffer == buffer)
				_positionsBuffer.removeEventListener(Event.CHANGE, onPositionsChange);
			if(_normalsBuffer == buffer)
				_normalsBuffer.removeEventListener(Event.CHANGE, onNormalsChange);
			if(_tangentsBuffer == buffer)
				_tangentsBuffer.removeEventListener(Event.CHANGE, onTangentsChange);
			if(_jointIndexProxy == buffer)
				_jointIndexProxy = null;
			if(_jointWeightsProxy == buffer)
				_jointWeightsProxy = null;
			
			super.removeVertexBufferSelector(selector);
		}
		
		public function get jointsPerVertex():int
		{
			return _jointsPerVertex;
		}

		/**
		 * If indices have been condensed, this will contain the original index for each condensed index.
		 */
		public function get condensedIndexLookUp() : Vector.<uint>
		{
			return _condensedIndexLookUp;
		}

		/**
		 * The amount of joints used when joint indices have been condensed.
		 */
		public function get numCondensedJoints() : uint
		{
			return _numCondensedJoints;
		}
		
		public function get jointWeightsProxy() : VertexBufferProxy
		{
			return _jointWeightsProxy;
		}
		
		public function get jointIndexProxy() : VertexBufferProxy
		{
			return _jointIndexProxy;
		}

		/**
		 * The animated vertex normals when set explicitly if the skinning transformations couldn't be performed on GPU.
		 */
		public function get animatedNormalData() : Vector.<Number>
		{
			return _normalsBuffer != null ? _normalsBuffer.dataVariation : null;
		}

		public function set animatedNormalData(value : Vector.<Number>) : void
		{
			if(_normalsBuffer == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.NORMALS, null, 3));
			
			_normalsBuffer.dataVariation = value;
		}

		/**
		 * The animated vertex tangents when set explicitly if the skinning transformations couldn't be performed on GPU.
		 */
		public function get animatedTangentData() : Vector.<Number>
		{
			return _tangentsBuffer != null ? _tangentsBuffer.dataVariation : null;
		}

		public function set animatedTangentData(value : Vector.<Number>) : void
		{
			if(_tangentsBuffer == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.TANGENTS, null, 3));
			
			_tangentsBuffer.dataVariation = value;
		}

		/**
		 * The animated vertex positions when set explicitly if the skinning transformations couldn't be performed on GPU.
		 */
		public function get animatedVertexData() : Vector.<Number>
		{
			return _positionsBuffer != null ? _positionsBuffer.dataVariation : null;
		}

		public function set animatedVertexData(value : Vector.<Number>) : void
		{
			if(_positionsBuffer == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.POSITIONS, null, 3));
			
			_positionsBuffer.dataVariation = value;
		}

		/**
		 * Retrieves the VertexBuffer3D object that contains joint weights.
		 * @param context The Context3D for which we request the buffer
		 * @return The VertexBuffer3D object that contains joint weights.
		 */
		[Deprecated(replacement="getVertexBufferSelector(...) or jointWeightsProxy.getBuffer(...)")]
		public function getJointWeightsBuffer(stage3DProxy : Stage3DProxy) : VertexBuffer3D
		{
			return _jointWeightsProxy.getBuffer(stage3DProxy);
		}

		/**
		 * Retrieves the VertexBuffer3D object that contains joint indices.
		 * @param context The Context3D for which we request the buffer
		 * @return The VertexBuffer3D object that contains joint indices.
		 */
		[Deprecated(replacement="getVertexBufferSelector(...) or jointIndexProxy.getBuffer(...)")]
		public function getJointIndexBuffer(stage3DProxy : Stage3DProxy) : VertexBuffer3D
		{
			return _jointIndexProxy.getBuffer(stage3DProxy);
		}
		
		/**
		 * Clones the current object.
		 * @return An exact duplicate of the current object.
		 */
		override public function clone(cloneBuffers:Boolean=false) : SubGeometry
		{
			var selector:VertexBufferSelector;
			
			var clone:SkinnedSubGeometry = new SkinnedSubGeometry(_jointsPerVertex);
			
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
			
			clone._numCondensedJoints = _numCondensedJoints;
			clone._condensedIndexLookUp = _condensedIndexLookUp;
			
			return clone;
		}

		/**
		 */
		arcane function condenseIndexData() : void
		{
			var jointIndexData:Vector.<Number> = _jointIndexProxy.data;
			
			var len : int = jointIndexData.length;
			var oldIndex : int;
			var newIndex : int = 0;
			var dic : Dictionary = new Dictionary();

			var condensedJointIndexData:Vector.<Number> = new Vector.<Number>(len, true);
			_condensedIndexLookUp = new Vector.<uint>();

			for (var i : int = 0; i < len; ++i) {
				oldIndex = jointIndexData[i];

				// if we encounter a new index, assign it a new condensed index
				if (dic[oldIndex] == undefined) {
					dic[oldIndex] = newIndex;
					_condensedIndexLookUp[newIndex++] = oldIndex;
					_condensedIndexLookUp[newIndex++] = oldIndex+1;
					_condensedIndexLookUp[newIndex++] = oldIndex+2;
				}
				condensedJointIndexData[i] = dic[oldIndex];
			}
			_numCondensedJoints = newIndex/3;
			
			_jointIndexProxy.dataVariation = condensedJointIndexData;
		}


		/**
		 * The raw joint weights data.
		 */
		arcane function get jointWeightsData() : Vector.<Number>
		{
			return _jointWeightsProxy != null ? _jointWeightsProxy.data : null;
		}

		arcane function updateJointWeightsData(value : Vector.<Number>) : void
		{
			// invalidate condensed stuff
			_numCondensedJoints = 0;
			_condensedIndexLookUp = null;

			if(_jointWeightsProxy == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.JOINT_WEIGHTS, value, _jointsPerVertex));
			else
				_jointWeightsProxy.data = value;
		}

		/**
		 * The raw joint index data.
		 */
		arcane function get jointIndexData() : Vector.<Number>
		{
			return _jointIndexProxy != null ? _jointIndexProxy.data : null;
		}

		arcane function updateJointIndexData(value : Vector.<Number>) : void
		{
			if(_jointIndexProxy == null)
				addVertexBuffer(new VertexBufferProxy(VertexBufferUsages.JOINT_INDICES, value, _jointsPerVertex));
			else
				_jointIndexProxy.data = value;
		}
		
		private function onPositionsChange(event:Event):void
		{
			_positionsBuffer.dataVariation.length = _positionsBuffer.data.length;		// make animated vertex data have the same length as source data
		}
		
		private function onNormalsChange(event:Event):void
		{
			_normalsBuffer.dataVariation.length = _normalsBuffer.data.length;		// make animated vertex data have the same length as source data
		}
		
		private function onTangentsChange(event:Event):void
		{
			_tangentsBuffer.dataVariation.length = _tangentsBuffer.data.length;		// make animated vertex data have the same length as source data
		}
	}
}
