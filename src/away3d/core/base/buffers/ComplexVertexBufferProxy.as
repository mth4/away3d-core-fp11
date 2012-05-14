package away3d.core.base.buffers
{
	public class ComplexVertexBufferProxy extends VertexBufferProxy
	{
		/*
		* PUBLIC
		*/
		/**
		 * Used to manage buffers that contain few types of data like position + color or 3 sets of uv's.
		 * @see away3d.core.base.buffers.VertexBufferSelector
		 */
		public function ComplexVertexBufferProxy(data:Vector.<Number>, dataPerVertex:uint)
		{
			super(null, data, dataPerVertex);
			
			_selectors = new Vector.<VertexBufferSelector>();
		}
		
		public function addSelector(usage:VertexBufferSelector):void
		{
			_selectors.push(usage);
		}
		
		override public function clone():VertexBufferProxy
		{
			var copy:ComplexVertexBufferProxy = new ComplexVertexBufferProxy(_data != null ? _data.concat() : null, _dataPerVertex);
			
			for each(var selector:VertexBufferSelector in _selectors)
				copy.addSelector(selector);
			
			if(_dataVariation != null)
				copy.dataVariation = _dataVariation.concat();
			
			return copy;
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