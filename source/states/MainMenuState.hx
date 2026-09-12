package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import substates.StoryMenuSubState;
import backend.WeekData;
import backend.Locking;

import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = 'Alpha V6';
	public static var curSelected:Int = 0;
	public static var gamever:String = 'ALPHA 6';
	public static var curColumn:MainMenuColumn = LEFT;
	var allowMouse:Bool = true;

	var menuItems:FlxSpriteGroup;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;
	var balloonText:FlxText;
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'charselect', #end
		'credits'
	];

	var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'mission' #else null #end;
	var rightOption:String = 'options';
	
	var magenta:FlxSprite;
	var camFollow:FlxObject;

	var bg:FlxSprite;

	static var showOutdatedWarning:Bool = true;
	override function create()
	{
		balloonText = new FlxText(730, 170, 530, "", 32);
		balloonText.setFormat(Paths.font('title.otf'), 32, FlxColor.WHITE, CENTER);
		balloonText.scrollFactor.set(0, 0);
		balloonText.antialiasing = ClientPrefs.data.antialiasing;

		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("메인메뉴", null);
		#end

		persistentUpdate = persistentDraw = true;

		// 서브스테이트가 닫히면 메뉴 입력 잠금 해제 (섭스테이트 열고 닫으면 메뉴가 얼어버리는 문제 방지)
		subStateClosed.add(function(_) {
			selectedSomethin = false;
			magenta.visible = false;
			persistentUpdate = true;
		});

		var yScroll:Float = 0;
		bg = new FlxSprite(0,0).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuBG2'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(FlxG.width,FlxG.height);
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		add(magenta);

		menuItems = new FlxSpriteGroup();
		add(menuItems);

		var g = FlxG.random.getObject(getIntroTextShit());

		var result:String = "";
		for (i in g) {
			result += i+'\n';
		}
		balloonText.text = result;
		add(balloonText);

		WeekData.reloadWeekFiles();

		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, (num * 100) + 30);
			item.ID = num;
			if (option == 'story_mode' || option == 'freeplay' || option == 'charselect' || option == 'credits')
			{
        		item.y -= 15;
    		}
			if (option == 'freeplay' || option == 'charselect')
			{
        		if (Locking.isLocked(option)) item.color = FlxColor.GRAY;
    		}
			item.y += (4 - optionShit.length) * 70;
			item.x = 50;
		}

		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 25, 425);
			if (Locking.isLocked(leftOption)) leftItem.color = FlxColor.GRAY;
		}
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, 250, 425);
		}

		menuItems.scale.set(0.75, 0.75);
		menuItems.y += 40;
		for (memb in menuItems)
		{
    		memb.updateHitbox();
    		var targetX:Float = memb.x;
    		var targetY:Float = memb.y;
    		memb.x -= 300; // 여기서 옆으로 밀어놓기
    		FlxTween.tween(memb, {x: targetX, y: targetY}, 1.0, {ease: FlxEase.cubeIn});
		}

		
		var psychVer:FlxText = new FlxText(12, FlxG.height - 66, 0, Language.getPhrase('psychVer','Legend Engine Version: ') + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 45, 0, Language.getPhrase( 'fnfVer','FNF Version: ') + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		var gameVer:FlxText = new FlxText(12, FlxG.height - 24, 0, Language.getPhrase('gameVer', "Mod's Ver: ") + gamever, 12);
		gameVer.scrollFactor.set();
		gameVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(gameVer);
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		if (menuItem.frames == null) // 아틀라스 없으면 안 띄우기
		{
			FlxG.log.error('MainMenu: "menu_$name" 아틀라스를 찾을 수 없음');
			return menuItem;
		}
		menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
		menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
		menuItem.animation.play('idle');
		menuItem.updateHitbox();

		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		if (menuItem.frames != null)
			menuItems.add(menuItem);
		return menuItem;
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;

	function getIntroTextShit():Array<Array<String>>
		{
    		#if MODS_ALLOWED
    		var firstArray:Array<String> = Mods.mergeAllTextsNamed('data/balloonText.txt');
    		#else
    		var fullText:String = Assets.getText(Paths.txt('balloonText'));
    		var firstArray:Array<String> = fullText.split('\n');
    		#end
    		var swagGoodArray:Array<Array<String>> = [];
    		for (i in firstArray)
    		{
        		swagGoodArray.push(i.split('--'));
    		}
    		return swagGoodArray;
		}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed))
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch(curColumn)
				{
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case LEFT:
						selectedItem = leftItem;
					case RIGHT:
						selectedItem = rightItem;
				}

				if(leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					allowMouse = true;
					if(selectedItem != leftItem)
					{
						curColumn = LEFT;
						changeItem();
					}
				}
				else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					allowMouse = true;
					if(selectedItem != rightItem)
					{
						curColumn = RIGHT;
						changeItem();
					}
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if(distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if(timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch(curColumn)
			{
				case CENTER:
					if(controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}
					else if(controls.UI_RIGHT_P && rightOption != null)
					{
						curColumn = RIGHT;
						changeItem();
					}

				case LEFT:
					if(controls.UI_RIGHT_P)
					{
						curColumn = CENTER;
						changeItem();
					}

				case RIGHT:
					if(controls.UI_LEFT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse))
			{
				var item:FlxSprite;
				var option:String;

				switch(curColumn)
				{
					case CENTER:
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];

					case LEFT:
						option = leftOption;
						item = leftItem;

					case RIGHT:
						option = rightOption;
						item = rightItem;
				}

				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					magenta.visible = true;

				switch (option)
				{
					case 'story_mode':
						openSubState(new substates.StoryMenuSubState());
						FlxG.keys.reset();

					case 'freeplay':
						if (Locking.isLocked("freeplay")) {
							openSubState(new substates.ErrorSubstate(Language.getPhrase("blocked", "Menu blocked!!\nPlay game, and unlock menu~!")));
							FlxG.keys.reset();
						}
						else {
							MusicBeatState.switchState(new FreeplayState());
						}

					#if MODS_ALLOWED
					case 'charselect':
						if (Locking.isLocked("charselect")) {
							openSubState(new substates.ErrorSubstate(Language.getPhrase("blocked", "Menu blocked!!\nPlay game, and unlock menu~!")));
							FlxG.keys.reset();
						}
						else {
							MusicBeatState.switchState(new CharacterSelectState());
						}
					#end

					#if ACHIEVEMENTS_ALLOWED
					case 'mission':
						if (Locking.isLocked("mission")) {
							openSubState(new substates.ErrorSubstate(Language.getPhrase("blocked", "Menu blocked!!\nPlay game, and unlock menu~!")));
							FlxG.keys.reset();
						}
						else {
							MusicBeatState.switchState(new AchievementsMenuState());
						}
					#end

					case 'credits':
						MusicBeatState.switchState(new CreditsState());
					case 'options':
    					options.OptionsState.onPlayState = false;
    					openSubState(new options.OptionsSubState());
    					FlxG.keys.reset();
    					if (PlayState.SONG != null)
    					{
        					PlayState.SONG.arrowSkin = null;
        					PlayState.SONG.splashSkin = null;
        					PlayState.stageUI = 'normal';
    					}
					case 'donate':
						CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
						selectedSomethin = false;
						item.visible = true;
					default:
						trace('Menu Item ${option} doesn\'t do anything');
						selectedSomethin = false;
						item.visible = true;
				}

				// 잠긴 메뉴 제외, 해금된 메뉴 진입 시에만 항목 슬라이드
				if (!Locking.isLocked(option))
				{
					for (memb in menuItems)
					{
						if (memb == leftItem || memb == rightItem || optionShit[memb.ID] == 'story_mode') FlxTween.tween(memb, {x: FlxG.width + memb.width + 50}, 2, {ease: FlxEase.circOut});
						else FlxTween.tween(memb, {x: bg.x - memb.width - 50}, 2, {ease: FlxEase.cubeOut});
					}
				}
			}
			#if DEBUG
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function changeItem(change:Int = 0)
	{
		if(change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite;
		switch(curColumn)
		{
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
	}
}
