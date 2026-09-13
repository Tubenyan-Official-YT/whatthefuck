package states;

import backend.Gamatoto;
import backend.Adventure;
import backend.Conductor;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import objects.Window;
import openfl.utils.AssetType;
import flixel.text.FlxText.FlxTextBorderStyle;

/**
 * 가마토토 탐험 화면.
 * TODO: adventureNames는 임시 placeholder임. 실제 모험 목록으로 교체 필요.
 * 가마토토 관련 이미지는 전부 images/gamatoto/ 안에 위치 (없으면 자동으로 대체 그래픽 사용).
 * 언락: Gamatoto.unlockedNames에 이름 저장됨. Lua에서 unlockGamatoto(name) 함수로 풀어줌.
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
	var curWindow:Window;
	var windowTexts:Array<FlxText> = [];
	var windowTitle:FlxText; // 창 위쪽에 모험 이름 표시 (창 이미지는 통일해서 씀)

	// idle: 창 닫힌 상태, carousel: 모험/시간 선택중, status: 진행중/완료 표시
	var uiState:String = "idle";


	override function create()
	{
		cropOverlay = false; // 가마토토 화면은 오버레이로 안 자름

		// 예전에 플레이한 곡의 bpmChangeMap이 static이라 그대로 남아있어서
		// 메인메뉴 곡 시간이랑 안 맞는 엉뚱한 stepCrochet이 나옴 -> 여기서 초기화
		Conductor.bpmChangeMap = [];

		Gamatoto.init();

		// 첫 실행이면 첫 모험만 언락
		if (Gamatoto.unlockedNames.length == 0)
			Gamatoto.unlock(adventureNames[0]);

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
			catSprite.animation.addByPrefix('idle', 'idle', 12, false);
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

	// FlxG.mouse.overlaps(obj)는 카메라 쪼가리에서 널참조 나길래
	// FlxPointer 안 타는 좌표 직접비교로 완전히 회피
	function mouseOverlaps(obj:FlxSprite):Bool
	{
		if (obj == null) return false;
		return FlxG.mouse.x >= obj.x && FlxG.mouse.x <= obj.x + obj.width
			&& FlxG.mouse.y >= obj.y && FlxG.mouse.y <= obj.y + obj.height;
	}

	override function beatHit()
	{
		super.beatHit();
		catSprite.animation.play('idle', true);
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

	// 창 이미지는 gamatoto/window 하나로 통일. 이름은 위쪽에 텍스트로 표시
	function openAdventureWindow()
	{
		closeWindow(false);

		var name:String = adventureNames[curAdIndex];
		var locked:Bool = !Gamatoto.isUnlocked(name);

		curWindow = new Window('gamatoto/window', 0, true, true);
		add(curWindow);

		windowTitle = new FlxText(0, 20, 300, name, 28);
		windowTitle.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
		windowTitle.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 5, 1);
		curWindow.addItemAt(0, 10, windowTitle);
		windowTitle.antialiasing = ClientPrefs.data.antialiasing;

		if (locked)
		{
			var lockedText:FlxText = new FlxText(0, 100, 300, "아직 잠겨있음", 24);
			lockedText.antialiasing = ClientPrefs.data.antialiasing;
			lockedText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.GRAY, CENTER);
			lockedText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 5, 1);
			curWindow.addItemAt(0, 100, lockedText);
			windowTexts.push(lockedText);
		}
		else
		{
			for (i in 0...durationLabels.length)
			{
				var t:FlxText = new FlxText(0, 0, 200, durationLabels[i], 24);
				t.antialiasing = ClientPrefs.data.antialiasing;
				t.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
				t.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 5, 1);
				curWindow.addItemAt(50, 60 + i * 50, t);
				windowTexts.push(t);
			}
			updateDurationHighlight();
		}
	}

	function openStatusWindow()
	{
		closeWindow(false);

		curWindow = new Window('gamatoto/window', 0, true, true);
		add(curWindow);

		windowTitle = new FlxText(0, 20, 300, Gamatoto.curAd.name, 28);
		windowTitle.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER);
		t.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 5, 1);
		windowTitle.antialiasing = ClientPrefs.data.antialiasing;
		curWindow.addItemAt(0, 20, windowTitle);

		var t:FlxText = new FlxText(0, 0, 300, "", 24);
		t.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
		t.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 5, 1);
		t.antialiasing = ClientPrefs.data.antialiasing;
		curWindow.addItem("screenCenter", t);
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
		windowTitle = null;
		windowTexts = [];
		if (fullClose) uiState = "idle";
	}

	function startSelectedAdventure()
	{
		var name:String = adventureNames[curAdIndex];
		if (!Gamatoto.isUnlocked(name)) return; // 잠긴 모험은 시작 불가

		FlxG.sound.play(Paths.sound('confirmMenu'));
		var ad:Adventure = new Adventure(name, durations[curDuration]);
		ad.isLocked = false;
		Gamatoto.startAdventure(ad);
		closeWindow();
	}

	override function update(elapsed:Float)
	{
		// 메인메뉴 음악(freakyMenu)이 계속 흐르는 중이라 그거 기준으로 Conductor 갱신
		// (PlayState 밖에서는 Conductor.songPosition이 자동으로 안 흐름)
		if (FlxG.sound.music != null && FlxG.sound.music.playing)
			Conductor.songPosition = FlxG.sound.music.time;

		super.update(elapsed);

		switch (uiState)
		{
			case "idle":
				var clickedEntry:Bool = FlxG.mouse.justPressed
					&& (mouseOverlaps(catSprite));
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
					if (Gamatoto.isUnlocked(adventureNames[curAdIndex]))
					{
						curDuration = FlxMath.wrap(curDuration + (controls.UI_UP_P ? -1 : 1), 0, durationLabels.length - 1);
						FlxG.sound.play(Paths.sound('scrollMenu'));
						updateDurationHighlight();
					}
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
				else if (FlxG.mouse.justPressed && Gamatoto.isUnlocked(adventureNames[curAdIndex]))
				{
					for (i in 0...windowTexts.length)
					{
						if (mouseOverlaps(windowTexts[i]))
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
					if (controls.ACCEPT || (FlxG.mouse.justPressed && mouseOverlaps(t)))
					{
						FlxG.sound.play(Paths.sound('confirmMenu'));
						Gamatoto.claim();
						closeWindow();
					}
				}
				else
				{
					var remain:Float = Gamatoto.getRemaining();
					t.text = "남은시간: " + Std.int(remain / 60) + "분";
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
