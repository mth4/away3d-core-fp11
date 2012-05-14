package away3d.core.base.buffers
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.library.assets.NamedAssetBase;
	
	import flash.display3D.IndexBuffer3D;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	
	use namespace arcane;
	
	public class IndexBufferProxy extends NamedAssetBase
	{
		private var _indices:Vector.<uint>;
		private var _numIndices:uint;
		
		private var _owners:Array = new Array();
		
		private var _buffersDirtyRanges:Vector.<Vector.<Range>> = new Vector.<Vector.<Range>>(8);
		private var _buffers:Vector.<IndexBuffer3D> = new Vector.<IndexBuffer3D>(8);
		
		/*
		* PUBLIC
		*/
		public function IndexBufferProxy(indices:Vector.<uint>)
		{
			super();
			
			_indices = indices;
			_numIndices = indices.length;
		}
		
		public function addOwner(owner:Object):void
		{
			_owners.push(owner);
		}
		
		public function removeOwner(owner:Object):void
		{
			var index:int = _owners.indexOf(owner);
			if(index != -1)
				_owners.splice(index, 1);
			
			if(_owners == null)
				dispose();
		}
		
		public function get numIndices():uint
		{
			return _numIndices;
		}
		
		public function get numTriangles():uint
		{
			return _numIndices / 3;
		}
		
		public function clone():IndexBufferProxy
		{
			var newIndices:Vector.<uint> = new Vector.<uint>(_numIndices);
			
			for(var i:uint=0; i<_numIndices; ++i)
				newIndices[i] = _indices[i];
			
			return new IndexBufferProxy(newIndices);
		}
		
		public function dispose():void
		{
			disposeBuffers();
			
			_buffers = null;
			_buffersDirtyRanges = null;
			_indices = null;
		}
		
		public function disposeForStage3D(stage3DProxy:Stage3DProxy):void
		{
			var index:int = stage3DProxy._stage3DIndex;
			
			var buffer:IndexBuffer3D = _buffers[index];
			if(buffer != null)
			{
				buffer.dispose();
				_buffers[index] = null;
			}
			
			_buffersDirtyRanges[index] = null;
		}
		
		public function invertTriangles():void
		{
			for(var i:uint=0; i<_numIndices; i+=3)
			{
				var t:uint = _indices[i];
				_indices[i] = _indices[i+2];
				_indices[i+2] = t;
			}
			
			invalidateContent();
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
			
			_numIndices = _indices.length;
			
			dispatchEvent(new Event(Event.CHANGE));
		}
		
		public function invalidateSize():void
		{
			disposeBuffers();
		}
		
		/**
		 * Completely invalidates buffer contents without invalidating it's size.
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
			endVertex = Math.min(endVertex, _indices.length);
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
					_buffersDirtyRanges[i] = Vector.<Number>([new Range(startVertex, endVertex)]);
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
		
		public function get indices():Vector.<uint>
		{
			return _indices;
		}
		
		public function set indices(val:Vector.<uint>):void
		{
			if(_indices.length != val.length)
			{
				_numIndices = val.length;
				disposeBuffers();
			}
			else
				invalidateContent();
			
			_indices = val;
		}
		
		public function getBuffer(stage3DProxy:Stage3DProxy):IndexBuffer3D
		{
			var contextIndex : int = stage3DProxy._stage3DIndex;
			
			var buffer:IndexBuffer3D = _buffers[contextIndex] as IndexBuffer3D;
			
			if(buffer == null)
			{
				_buffers[contextIndex] = buffer = stage3DProxy._context3D.createIndexBuffer(_indices.length);
				buffer.uploadFromVector(_indices, 0, _indices.length);
				
				_buffersDirtyRanges[contextIndex] = null;		// probably unnecessary
			}
			else
			{
				var ranges:Vector.<Range> = _buffersDirtyRanges[contextIndex] as Vector.<Range>;
				
				if(ranges != null)
				{
					for each(var range:Range in ranges)
						buffer.uploadFromVector(_indices, range.min, range.max-range.min);
					
					_buffersDirtyRanges[contextIndex] = null;
				}
			}
			
			return buffer;
		}
		
		/*
		* PROTECTED
		*/
		
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