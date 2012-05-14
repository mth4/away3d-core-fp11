package away3d.core.base.buffers
{
	public class VertexBufferIterator
	{
		private var _selector:VertexBufferSelector;
		
		private var _position:uint=0;
		private var _counter:uint=0;
		private var _spacing:uint=0;
		
		private var _data:Vector.<Number>;
		private var _length:uint;
		
		/*
		* PUBLIC
		*/
		public function VertexBufferIterator(selector:VertexBufferSelector)
		{
			_selector = selector;
			
			_position = _selector.offset;
			_counter = _selector.dataPerVertex;
			_spacing = _selector.bufferProxy.dataPerVertex - _counter + 1;
			
			_data = _selector.bufferProxy.data;
			_length = _data.length;
		}
		
		public function hasNext():Boolean
		{
			if(_counter == 1)
				return _position + _spacing < _length;
			else
				return _position + 1 < _length;
		}
		
		public function next():Number
		{
			if(--_counter == 0)
			{
				_counter = _selector.dataPerVertex;
				_position += _spacing;
			}
			else
				_position++;
			
			return _data[_position];
		}
		
		public function get currentValue():Number
		{
			return _data[_position];
		}
		
		public function set currentValue(val:Number):void
		{
			_data[_position] = val;
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