package away3d.materials.methods
{
	import away3d.arcane;
	import away3d.core.managers.Stage3DProxy;
	import away3d.materials.methods.ShadingMethodBase;
	import away3d.materials.utils.ShaderRegisterCache;
	import away3d.materials.utils.ShaderRegisterElement;
	import away3d.textures.Texture2DBase;
	
	import flash.display3D.Context3DProgramType;
	
	use namespace arcane;
	
	public class BasicIlluminationMethod extends ShadingMethodBase
	{
		private var _illuminationMap:Texture2DBase;
		
		private var _constantsData:Vector.<Number> = new Vector.<Number>(4, true);
		
		private var _constantsIndex:int;
		private var _textureIndex:int;
		
		/*
		* PUBLIC
		*/
		/**
		 * It samples a texture which is always visible without any lights impact. It looks like it would illuminate.
		 */
		public function BasicIlluminationMethod(tex:Texture2DBase=null)
		{
			super(false, false, false);
			
			illuminationMap = tex;
			
			intensity = 1;
			
			_needsUV = true;
		}
		
		override public function copyFrom(method:ShadingMethodBase):void
		{
			var m:BasicIlluminationMethod = BasicIlluminationMethod(method);
			
			illuminationMap = m.illuminationMap;
			intensity = m.intensity;
		}
		
		public function set illuminationMap(tex:Texture2DBase):void
		{
			_illuminationMap = tex;
		}
		
		public function get illuminationMap():Texture2DBase
		{
			return _illuminationMap;
		}
		
		public function set intensity(value:Number):void
		{
			if((value == 1) != (_constantsData[3] == 1))
				invalidateShaderProgram();
			
			_constantsData[3] = value;
		}
		
		public function get intensity():Number
		{
			return _constantsData[3];
		}
		
		/*
		* PROTECTED
		*/
		override arcane function getFragmentPostLightingCode(registers:ShaderRegisterCache, targetReg:ShaderRegisterElement):String
		{
			var fcA:ShaderRegisterElement = registers.getFreeFragmentConstant();
			_constantsIndex = fcA.index;
			
			if(_illuminationMap != null)
			{
				var tex:ShaderRegisterElement = registers.getFreeTextureReg();
				_textureIndex = tex.index;
				
				var temp:ShaderRegisterElement = registers.getFreeFragmentVectorTemp();
				
				var uv:ShaderRegisterElement = _uvFragmentReg;
				
				var code:String = getTexSampleCode(temp, tex, uv);
				
				if(intensity != 1)
					code += "mul " + temp + ", " + temp + ", " + fcA + ".w\n";
				
				code += "add " + targetReg + ", " + targetReg + ", " + temp + "\n";
				
				return code;
			}
			
			return null;
		}
		
		override arcane function activate(stage3DProxy:Stage3DProxy):void
		{
			if(_illuminationMap != null)
				stage3DProxy.context3D.setTextureAt(_textureIndex, _illuminationMap.getTextureForStage3D(stage3DProxy));
			
			stage3DProxy.context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, _constantsIndex, _constantsData, 1);
		}
		
		/*
		* PRIVATE
		*/
		
		/*
		* PRIVATE - EVENTS
		*/
	}
}