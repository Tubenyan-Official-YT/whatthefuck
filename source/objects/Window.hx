package objects;
import backend.EasyJson;
import openfl.utils.AssetType;

class Window extends FlxSpriteGroup {
	// 변수들임.
	var mainWin:FlxSprite;
	var contents:FlxSpriteGroup;
	var offsetT:Int;
	var dimBG:FlxSprite;
	var cam:FlxCamera;

	var doAutoMove:Bool = false;
	var hasDim:Bool = true;
	
	var posMap:EasyJson;

	public function new(winImage:String, offsetF:Int, autoMove:Bool, hasDimF:Bool) {
		super();

		this.offsetT = offsetF;
		this.hasDim = hasDimF;

		if (hasDim) {
			//반투명배경
			dimBG = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
			dimBG.alpha = 0.5;
			dimBG.cameras = [FlxG.camera];
			add(dimBG);
		}
		
		// 이미지 없으면 검은 네모 하나로 대체
		if (Paths.fileExists('images/${winImage}.png', IMAGE))
			mainWin = new FlxSprite(0, 0).loadGraphic(Paths.image(winImage));
		else
			mainWin = new FlxSprite(0, 0).makeGraphic(300, 300, FlxColor.BLACK);
		mainWin.screenCenter();
		mainWin.antialiasing = ClientPrefs.data.antialiasing;
		mainWin.updateHitbox();
		add(mainWin);
		
		posMap = new EasyJson('${winImage}Set');
		
		contents = new FlxSpriteGroup();
		add(contents);

		if (autoMove) { 
			doAutoMove = true;
		}
		refreshCam();
	}

	public function refreshWin() {
		if (doAutoMove) {
			mainWin.screenCenter();
			contents.x = mainWin.x + mainWin.width - contents.width;
			contents.y = mainWin.y + offsetT;
		}
	}
	public function refreshCam() {
		if (cam != null) {
			cam.zoom = cam.width / mainWin.width;
			cam.x = mainWin.x;
			cam.y = mainWin.y + offsetT;
			cam.width = Std.int(mainWin.width);
			cam.height = Std.int(mainWin.height - offsetT);
		}
		else {
			cam = new FlxCamera(mainWin.x, mainWin.y + offsetT, Std.int(mainWin.width), Std.int(mainWin.height - offsetT));
			cam.bgColor = 0x00000000; // 창 배경이 그대로 보이도록 투명 처리
			FlxG.cameras.add(cam, false);
		}
	}
	
	public function destroyCam()
	{
		if (cam != null)
		{
			FlxG.cameras.remove(cam, true);
			cam = null;
		}
	}
	
	override function destroy()
	{
		destroyCam();
		super.destroy();
	}
	
	public function addItem(name:String, sprite:FlxSprite) {
		contents.add(sprite);
		if (name == "screenCenter") {
			sprite.x = mainWin.x + (mainWin.width - sprite.width) / 2;
			sprite.y = mainWin.y + (mainWin.height - sprite.height) / 2 + offsetT;
		}
		else {
			var pos:Dynamic = posMap.get(name);
			sprite.x = pos[0];
			sprite.y = pos[1];
		}
	}

	// 포지션 JSON(posMap) 없이, mainWin 기준 상대좌표로 바로 배치 (가마토토 창처럼 모험마다 배경이 바뀌는 경우용)
	public function addItemAt(x:Float, y:Float, sprite:FlxSprite) {
		contents.add(sprite);
		sprite.x = mainWin.x + x;
		sprite.y = mainWin.y + y + offsetT;
	}
	
	override function update(elapsed:Float) {
		if (hasDim && dimBG != null) dimBG.screenCenter();
		super.update(elapsed);
	}
}
