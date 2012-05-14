package away3d.core.base.buffers
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.errors.AbstractMethodError;
	import away3d.library.assets.NamedAssetBase;
	
	import flash.display3D.VertexBuffer3D;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import spark.components.supportClasses.Range;

	use namespace arcane;
	
	public class VertexBufferProxy extends NamedAssetBase
	{
		protected var _selectors:Vector.<VertexBufferSelector>;
		
		private var _owners:Array = new Array();
		
		protected var _data:Vector.<Number>;				// static buffer data
		protected var _dataVariation:Vector.<Number>;
		protected var _dataPerVertex:uint;
		protected var _numVertices:uint;
		
		private var _buffersDirtyRanges:Vector.<Vector.<Range>> = new Vector.<Vector.<Range>>(8);
		private var _buffers:Vector.<VertexBuffer3D> = new Vector.<VertexBuffer3D>(8);
		
		/*
		* PUBLIC
		*/
		/**
		 * Default proxying class for vertex buffers. It is designed to work with uniform buffers like buffers containing only position or uv data, but not both as it is a purpose of ComplexVertexBufferProxy.
		 * @param usage It may be one of the default usages of VertexBufferUsages class or some custom usage. It determines for what the buffer will be used for. Use ComplexVertexBufferProxy to get multiple usages support.
		 * @param data Buffer contents.
		 * @param dataPerVertex How much data is going to be associated with each vertex.
		 */
		public function VertexBufferProxy(usage:String, data:Vector.<Number>, dataPerVertex:uint)
		{
			_data = data;
			
			if(dataPerVertex == 0)
			{
				switch(usage)
				{
					case VertexBufferUsages.POSITIONS:
					case VertexBufferUsages.NORMALS:
					case VertexBufferUsages.TANGENTS:
						_dataPerVertex = 3;
						break;
					
					case VertexBufferUsages.UV:
						_dataPerVertex = 2;
						break;
					
					default:
						throw new Error("Data per vertex must be defined");
				}
			}
			else
				_dataPerVertex = dataPerVertex;
			
			_selectors = new Vector.<VertexBufferSelector>(1, true);
			_selectors[0] = new VertexBufferSelector(this, usage, 0, 0);
			
			_numVertices = _data != null && _dataPerVertex != 0 ? _data.length / _dataPerVertex : 0;
		}
		
		arcane function addOwner(owner:Object):void
		{
			_owners.push(owner);
		}
		
		arcane function removeOwner(owner:Object):void
		{
			var index:int = _owners.indexOf(owner);
			if(index != -1)
				_owners.splice(index, 1);
			
			if(_owners == null)
				dispose();
		}
		
		public function clone():VertexBufferProxy
		{
			var clone:VertexBufferProxy = new VertexBufferProxy(_selectors[0].usage, _data != null ? _data.concat() : null, _dataPerVertex);
			
			if(_dataVariation != null)
				clone.dataVariation = _dataVariation.concat();
			
			return clone;
		}
		
		public function dispose():void
		{
			disposeBuffers();
			
			_buffers = null;
			_buffersDirtyRanges = null;
			_data = null;
			_dataVariation = null;
			_selectors = null;
		}
		
		public function disposeForStage3D(stage3DProxy:Stage3DProxy):void
		{
			var index:int = stage3DProxy._stage3DIndex;
			
			var buffer:VertexBuffer3D = _buffers[index];
			if(buffer != null)
			{
				buffer.dispose();
				_buffers[index] = null;
			}
			
			_buffersDirtyRanges[index] = null;
		}
		
		/**
		 * Fills buffer with zeroes.
		 */
		public function clear():void
		{
			var len:uint = _data.length;
			for(var i:uint=0; i<len; ++i)
				_data[i] = 0.0;
		}
		
		public function get selectors():Vector.<VertexBufferSelector>
		{
			return _selectors;
		}
		
		public function get dataPerVertex():uint
		{
			return _dataPerVertex;
		}
		
		public function set dataPerVertex(value:uint):void
		{
			_dataPerVertex = value;
			
			_numVertices = priorityData.length / _dataPerVertex;
			
			disposeBuffers();
		}
		
		public function get length():uint
		{
			return priorityData.length;
		}
		
		/**
		 * Count of vertices associated with this buffer. Setting this property may trim the source data.
		 */
		public function get numVertices():uint
		{
			return _numVertices;
		}
		
		public function set numVertices(value:uint):void
		{
			_numVertices = value;
			
			if(_data != null)
				_data.length = value * _dataPerVertex;
			
			if(_dataVariation != null)
				_dataVariation.length = value * _dataPerVertex;
			
			disposeBuffers();
		}
		
		/**
		 * Transformed/processed data which may change in time or get disabled. It always have higher priority than static data. It may be used to animate buffer on cpu or for any kind of variations of source data like condensed joint indices.
		 */
		public function get dataVariation():Vector.<Number>
		{
			return _dataVariation;
		}
		
		public function set dataVariation(value:Vector.<Number>):void
		{
			if(_dataVariation == value)
				return;
			
			var previousBufferLen:uint = _dataVariation == null ? _data.length : _dataVariation.length;
			var newBufferLen:uint = value == null ? _data.length : value.length;
			
			_dataVariation = value;
			
			if(previousBufferLen != newBufferLen)
			{
				_numVertices = newBufferLen / _dataPerVertex;
				disposeBuffers();
			}
			else
				invalidateContent();
		}
		
		/**
		 * Data stored in the buffer.
		 */
		public function get data():Vector.<Number>
		{
			return _data;
		}
		
		public function set data(value:Vector.<Number>):void
		{
			if(_data == value)
				return;
			
			var oldData:Vector.<Number> = _data;
			
			_data = value;
			
			if(_dataVariation == null)
			{
				if(_data == null || value.length != oldData.length)
				{
					_numVertices = value.length / _dataPerVertex;
					disposeBuffers();
				}
				else
					invalidateContent();
			}
		}
		
		public function disposeBuffers():void
		{
			for(var i:uint=0; i<8; ++i)
			{
				if(_buffers[i] != null)
				{
					_buffers[i].dispose();
					_buffers[i] = null;
				}
				
				_buffersDirtyRanges[i] = null;
			}
			
			_numVertices = priorityData.length / _dataPerVertex;
			
			dispatchEvent(new Event(Event.CHANGE));
		}
		
		/**
		 * Invalidated current buffer size. Call this method after changing data's vector length.
		 */
		public function invalidateSize():void
		{
			disposeBuffers();
		}
		
		/**
		 * Completely invalidates buffer contents.
		 */
		public function invalidateContent():void
		{
			invalidateContentRange(0, 0xFFFFFFFF);
		}
		
		/**
		 * Invalidates range of source data.
		 */
		public function invalidateContentRange(startVertex:uint, endVertex:uint):void
		{
			endVertex = Math.min(endVertex, _numVertices);
			startVertex = Math.min(startVertex, endVertex);
			
			if(startVertex == endVertex)
				return;
			
			// merge overlapping ranges
			for(var i:uint=0; i<8; ++i)
			{
				if(_buffers[i] == null)		// if there is no buffer, there is no point in invalidating content
					continue;
				
				var ranges:Vector.<Range> = _buffersDirtyRanges[i];
				
				if(ranges == null)
				{
					_buffersDirtyRanges[i] = Vector.<Range>([new Range(startVertex, endVertex)]);
					continue;
				}
				
				var numRanges:uint = ranges.length;
				
				for(var j:uint=0; j<numRanges; ++j)
				{
					var range:Range = ranges[j];
					
					if(startVertex <= range.max && endVertex >= range.max)
					{
						if(startVertex < range.min)
							range.min = startVertex;
						
						range.max = endVertex;
							
						for(; j<numRanges; ++j)
						{
							var range2:Range = ranges[j];
							if(endVertex >= range2.min)
								range.max = Math.max(endVertex, range2.max);
							ranges.splice(j, 1);
							j--; numRanges--;
						}
						
						break;
					}
					else if(startVertex <= range.min)
					{
						if(endVertex >= range.min)
							range.min = startVertex;
						else
							ranges.splice(j, 0, new Range(startVertex, endVertex));
						
						break;
					}
				}
			}
			
			dispatchEvent(new Event(Event.CHANGE));
		}
		
		/**
		 * Retrieves a buffer instance for the given context.
		 */
		public function getBuffer(stage3DProxy:Stage3DProxy):VertexBuffer3D
		{
			var contextIndex : int = stage3DProxy._stage3DIndex;
			
			var buffer:VertexBuffer3D = _buffers[contextIndex] as VertexBuffer3D;
			
			if(buffer == null)
			{
				_buffers[contextIndex] = buffer = stage3DProxy._context3D.createVertexBuffer(_numVertices, _dataPerVertex);
				buffer.uploadFromVector(priorityData, 0, _numVertices);
			}
			else
			{
				var ranges:Vector.<Range> = _buffersDirtyRanges[contextIndex] as Vector.<Range>;
				
				if(ranges != null)
				{
					for each(var range:Range in ranges)
						buffer.uploadFromVector(priorityData.slice(range.min * _dataPerVertex, range.max * _dataPerVertex), range.min, range.max-range.min);
					
					_buffersDirtyRanges[contextIndex] = null;
				}
			}
			
			return buffer;
		}
		
		/*
		* PROTECTED
		*/
		protected function get priorityData():Vector.<Number>
		{
			return _dataVariation != null ? _dataVariation : _data;
		}
		
		/*
		* PRIVATE
		*/
		
		/*
		* PRIVATE - EVENTS
		*/
	}
}

class Range
{
	public var min:uint;
	public var max:uint;
	
	public function Range(min:uint, max:uint)
	{
		this.min = min;
		this.max = max;
	}
}