package states;

import backend.Gamatoto;
import backend.Adventure;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import objects.Window;
import openfl.utils.AssetType;

/**
 * 가마토토 탐험 화면.
 * TODO: adventureNames는 임시 placeholder임. 실제 모험 목록으로 교체 필요.
 * 가마토토 관련 이미지는 전부 images/gamatoto/ 안에 위치 (없으면 자동으로 대체 그래픽 사용).
 */
class GamatotoState extends MusicBeatState
{
	var adventureNames:Array<String> = ["평화 초원", "쿵후 왕국", "사바의 사막"];
	var durations:Array<Float> = [3600, 3600 * 3, 3600 * 6]; // 1h, 3h, 6h
	var durationLabels:Array<String> = ["1시간", "3시간", "6시간"];

	// 배경 이미지 없을 때 쓸 진한 초록색 (안 쨍하게)
	static inline var FALLBACK_BG_COLOR:FlxColor = 0xFF234433;

	var curAdIndex:Int = 0;
	var curDuration:Int = 0;

	var catSprite:FlxSprite;
	var promptText:FlxText; // TODO: 임시 말풍선 텍스트, 나중에 실제 말풍선 그래픽으로 교체
	var curWindow:Window;
	var windowTexts:Array<FlxText> = [];

	// idle: 창 닫힌 상태, carousel: 모험/시간 선택중, status: 진행중/완료 표시
	var uiState:String = "idle";

	var camGamatoto:flixel.FlxCamera;

	override function create()
	{
		cropOverlay = false; // 가마토토 화면은 오버레이로 안 자름
		// 에디터류(ChartingState 등)처럼 cropOverlay=false일 때 카메라가 1개뿐이면
		// FlxG.mouse.overlaps()가 카메라 참조를 못 찾아 NullObjectReference를 던짐.
		// 그래서 카메라를 명시적으로 만들어 넘겨줌 (StageEditorState의 camHUD 패턴과 동일)
		camGamatoto = initPsychCamera();
		// initPsychCamera가 만든 카메라 하나뿐이면 FlxG.mouse.overlaps()가 깨지길래
		// 에디터류(camHUD)처럼 카메라를 하나 더 추가해서 리스트를 2개 이상으로 유지
		var dummyCam:flixel.FlxCamera = new flixel.FlxCamera();
		dummyCam.bgColor.alpha = 0;
		FlxG.cameras.add(dummyCam, false);

		Gamatoto.init();

		FlxG.mouse.visible = true;

		var bg:FlxSprite = new FlxSprite();
		if (Paths.fileExists('images/gamatoto/bg.png', IMAGE))
		{
			bg.loadGraphic(Paths.image('gamatoto/bg'));
			bg.setGraphicSize(FlxG.width, FlxG.height);
			bg.updateHitbox();
		}
		else
		{
			bg.makeGraphic(FlxG.width, FlxG.height, FALLBACK_BG_COLOR);
		}
		bg.scrollFactor.set();
		add(bg);

		catSprite = new FlxSprite();
		if (Paths.fileExists('images/gamatoto/cat.png', IMAGE))
		{
			catSprite.frames = Paths.getSparrowAtlas('gamatoto/cat');
			catSprite.animation.addByPrefix('idle', 'idle', 24, true);
			catSprite.animation.play('idle');
			catSprite.antialiasing = ClientPrefs.data.antialiasing;
		}
		else
		{
			catSprite.makeGraphic(150, 150, FlxColor.BLACK);
		}
		catSprite.screenCenter();
		add(catSprite);

		super.create();
	}

	function openWindow()
	{
		if (Gamatoto.curAd != null)
		{
			uiState = "status";
			openStatusWindow();
		}
		else
		{
			uiState = "carousel";
			openAdventureWindow();
		}
	}

	function openAdventureWindow()
	{
		closeWindow(false);

		curWindow = new Window('gamatoto/' + adventureNames[curAdIndex], 0, true, true);
		add(curWindow);

		for (i in 0...durationLabels.length)
		{
			var t:FlxText = new FlxText(0, 0, 200, durationLabels[i], 24);
			t.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
			curWindow.addItemAt(50, 60 + i * 50, t);
			windowTexts.push(t);
		}
		updateDurationHighlight();
	}

	function openStatusWindow()
	{
		closeWindow(false);

		curWindow = new Window('gamatoto/' + Gamatoto.curAd.name, 0, true, true);
		add(curWindow);

		var t:FlxText = new FlxText(0, 0, 300, "", 24);
		t.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
		curWindow.addItemAt(30, 80, t);
		windowTexts.push(t);
	}

	function updateDurationHighlight()
	{
		for (i in 0...windowTexts.length)
			windowTexts[i].alpha = (i == curDuration) ? 1 : 0.6;
	}

	function closeWindow(fullClose:Bool = true)
	{
		if (curWindow != null)
		{
			remove(curWindow);
			curWindow.destroy();
			curWindow = null;
		}
		windowTexts = [];
		if (fullClose) uiState = "idle";
	}

	function startSelectedAdventure()
	{
		FlxG.sound.play(Paths.sound('confirmMenu'));
		var ad:Adventure = new Adventure(adventureNames[curAdIndex], durations[curDuration]);
		Gamatoto.startAdventure(ad);
		closeWindow();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		switch (uiState)
		{
			case "idle":
				var clickedEntry:Bool = FlxG.mouse.justPressed
					&& (FlxG.mouse.overlaps(catSprite, camGamatoto) || FlxG.mouse.overlaps(promptText, camGamatoto));
				if (controls.ACCEPT || clickedEntry)
				{
					FlxG.sound.play(Paths.sound('confirmMenu'));
					openWindow();
				}
				else if (controls.BACK)
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					MusicBeatState.switchState(new MainMenuState());
				}

			case "carousel":
				if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
				{
					curAdIndex = FlxMath.wrap(curAdIndex + (controls.UI_LEFT_P ? -1 : 1), 0, adventureNames.length - 1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
					openAdventureWindow();
				}
				else if (controls.UI_UP_P || controls.UI_DOWN_P)
				{
					curDuration = FlxMath.wrap(curDuration + (controls.UI_UP_P ? -1 : 1), 0, durationLabels.length - 1);
					FlxG.sound.play(Paths.sound('scrollMenu'));
					updateDurationHighlight();
				}
				else if (controls.ACCEPT)
				{
					startSelectedAdventure();
				}
				else if (controls.BACK)
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					closeWindow();
				}
				else if (FlxG.mouse.justPressed)
				{
					for (i in 0...windowTexts.length)
					{
						if (FlxG.mouse.overlaps(windowTexts[i], camGamatoto))
						{
							curDuration = i;
							startSelectedAdventure();
							break;
						}
					}
				}

			case "status":
				var t:FlxText = windowTexts[0];
				if (Gamatoto.curAd.completed)
				{
					t.text = "탐험 완료!\n엔터: 보상받기";
					if (controls.ACCEPT || (FlxG.mouse.justPressed && FlxG.mouse.overlaps(t, camGamatoto)))
					{
						FlxG.sound.play(Paths.sound('confirmMenu'));
						Gamatoto.claim();
						closeWindow();
					}
				}
				else
				{
					var remain:Float = Gamatoto.getRemaining();
					t.text = "남은시간: " + Std.int(remain/1000) + "분";
					if (remain <= 0) Gamatoto.init();
				}

				if (controls.BACK)
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					closeWindow();
				}
		}
	}
}
