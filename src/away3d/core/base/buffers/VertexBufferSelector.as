package away3d.core.base.buffers
{
	import away3d.arcane;

	use namespace arcane;
	
	public class VertexBufferSelector
	{
		private var _bufferProxy:VertexBufferProxy;
		
		private var _usage:String;
		private var _offset:uint;
		private var _dataPerVertex:uint;
		
		/*
		* PUBLIC
		*/
		/**
		 * VertexBufferSelector manages some subset of associated buffer's per-vertex data.
		 */
		public function VertexBufferSelector(bufferProxy:VertexBufferProxy, usage:String, offset:uint, dataPerVertex:uint)
		{
			_bufferProxy = bufferProxy;
			
			_usage = usage;
			_offset = offset;
			_dataPerVertex = dataPerVertex;
		}
		
		public function translate(...factors):void
		{
			var i:uint, j:uint;
			
			if(factors.length == 1)
			{
				var factor:Number = factors[0];
				factors = new Array();
				for(i=0; i<_dataPerVertex; ++i)
					factors[i] = factor;
			}
			else if(factors.length != _dataPerVertex)
				throw new Error("Count of factors specified must be equal to the dataPerVertex property.");
			
			var iter:VertexBufferIterator = createIterator();
			
			while(iter.hasNext())
				for(j=0; j<_dataPerVertex; ++j)
					iter.currentValue = iter.next() + factors[j];
			
			_bufferProxy.invalidateContent();
		}
		
		/**
		 * Scales selector components in a buffer by given factor/factors. There may be specified only one factor and all data will be multiplied by it. In the other case, there must be one factor for each dimension (which is equal to dataPerVertex property).
		 */
		public function scale(...factors):void
		{
			var i:uint, j:uint;
			
			if(factors.length == 1)
			{
				var factor:Number = factors[0];
				factors = new Array();
				for(i=0; i<_dataPerVertex; ++i)
					factors[i] = factor;
			}
			else if(factors.length != _dataPerVertex)
				throw new Error("Count of factors specified must be equal to the dataPerVertex property.");
			
			var iter:VertexBufferIterator = createIterator();
			
			while(iter.hasNext())
				for(j=0; j<_dataPerVertex; ++j)
					iter.currentValue = iter.next() * factors[j];
			
			_bufferProxy.invalidateContent();
		}
		
		public function createIterator():VertexBufferIterator
		{
			return new VertexBufferIterator(this);
		}
		
		public function get bufferProxy():VertexBufferProxy
		{
			return _bufferProxy;
		}
		
		/**
		 * Shorthand for bufferProxy.data
		 */
		public function get bufferData():Vector.<Number>
		{
			return _bufferProxy.data;
		}
		
		public function get usage():String
		{
			return _usage;
		}
		
		public function get offset():uint
		{
			return _offset;
		}
		
		public function get dataPerVertex():uint
		{
			return _dataPerVertex;
		}
		
		public function get format():String
		{
			return "float" + (_dataPerVertex != 0 ? _dataPerVertex : _bufferProxy.dataPerVertex);
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