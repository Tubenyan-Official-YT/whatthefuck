package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.EnergySystem;
import backend.Locking;

import backend.EasyJson;
import objects.EnemyList;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;
import openfl.utils.Assets;

import haxe.Json;

class FreeplayState extends MusicBeatState
{
	var songs:Array<SongMetadata> = [];
	var misses:Int = 0;
	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();
	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;
	
	private var grpSongs:FlxTypedGroup<FlxSprite>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];


	var diffButtons:Array<FlxSprite> = [];
	var charSelectBtn:FlxSprite;
	var startButton:FlxSprite;

	var energyTxt:FlxText;
	var energyBox:FlxSprite;

	var lsTxt:FlxText;
	
	var bg:FlxSprite;
	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	var freeplayUIGrp:FlxSpriteGroup;

	var currentEnemyList:EnemyList;

	
	function refreshDiffButtons():Void
	{
		for (btn in diffButtons) freeplayUIGrp.remove(btn);
		diffButtons = [];
		var btnY:Float = 110; // freeplayUIGrp.y 기준 상대좌표
		var spacing:Float = 70;

		for (i in 0...Difficulty.list.length) {
			var diffName:String = Paths.formatToSongPath(Difficulty.list[i]);
			var isSelected:Bool = (i == curDifficulty);
			// startButton.x는 이미 add() 때 그룹 오프셋이 적용된 절대좌표라서 x만 미리 빼서 상쇄시킴 (중복 오프셋 방지).
			// btnY는 그룹 기준 순수 상대값이라 그대로 두면 add()에서 정상적으로 한 번 오프셋됨.
			// i=0(맨 오른쪽 버튼)의 오른쪽 끝이 startButton의 리사이징된 오른쪽 끝과 맞도록 앵커.
			var btn:FlxSprite = new FlxSprite(startButton.x + startButton.width - i * spacing - freeplayUIGrp.x, btnY);
			btn.loadGraphic(Paths.image('freeplayDiff/$diffName-${isSelected ? "true" : "false"}'));
			btn.antialiasing = ClientPrefs.data.antialiasing;
			btn.scrollFactor.set();
			btn.ID = i;
			freeplayUIGrp.add(btn);
			diffButtons.push(btn);
		}
	}
	
	override function create()
	{
		freeplayUIGrp = new FlxSpriteGroup(800, 450); // 하단 오버레이에 안 걸리도록 위로 50px 올림
		
		if (FlxG.save.data.selectedSongGroup == null) {
			FlxG.save.data.selectedSongGroup = "bf_songs";
			FlxG.save.data.flush();
		}
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("프리플레이 메뉴", null);
		#end

		if(WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			openSubState(new substates.ErrorSubstate(Language.getPhrase("no_weeks", "NO WEEKS ADDED FOR FREEPLAY\n\nPress ACCEPT to go to the Week Editor Menu.\nPress BACK to return to Main Menu."),
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if(weekIsLocked(WeekData.weeksList[i])) continue;

			// [★ 수정 완료 ★] WeekData에서 지정된 캐릭터 폴더의 위크들만 이미 수집했으므로 잘못된 중복 필터링을 제거합니다.
			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();

		grpSongs = new FlxTypedGroup<FlxSprite>();
		add(grpSongs);
		for (i in 0...songs.length)
		{
			Mods.currentModDirectory = songs[i].folder;
			var songName:String = Paths.formatToSongPath(songs[i].songName);
			var songImage:FlxSprite = new FlxSprite(0, 120);

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[songs[i].week]);
			var baseDiff:String = 'normal';
			if (leWeek != null && leWeek.difficulties != null && leWeek.difficulties.trim() != '') {
				baseDiff = leWeek.difficulties.split(',')[0].trim();
			}

			var diffName:String = Paths.formatToSongPath(baseDiff);
			var imgPath:String = 'freeplay/' + songName + '-' + diffName;
			if ((Paths.fileExists((('images/' + imgPath) + '.png'), IMAGE))) {
				songImage.loadGraphic(Paths.image(imgPath));
			}
			else {
				var fallbackPath:String = 'freeplay/' + songName + '-normal';
				if ((Paths.fileExists((('images/' + fallbackPath) + '.png'), IMAGE))) {
					songImage.loadGraphic(Paths.image(fallbackPath));
				} 
				else {
					songImage.makeGraphic(1, 1, 0x00000000);
				}
			}
			songImage.setGraphicSize(0, 120);
			songImage.updateHitbox();
			songImage.antialiasing = ClientPrefs.data.antialiasing;
			songImage.ID = i;
			songImage.visible = songImage.active = false;
			grpSongs.add(songImage);
		}

		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(0, 80, 0, "", 24);
		scoreText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER);
		scoreText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 5);
		
		diffText = new FlxText(FlxG.width * 0.7, 5, 0, "", 24);
		diffText.screenCenter(X);
		diffText.font = scoreText.font;

		scoreBG = new FlxSprite(scoreText.x - 6, 150).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0;
		
		add(scoreBG);
		
		add(scoreText);
		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);
		
		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		charSelectBtn = new FlxSprite(0, 0); // freeplayUIGrp 기준 상대좌표
    	charSelectBtn.frames = Paths.getSparrowAtlas('freeplayUI/charSelectBtn');
    	charSelectBtn.animation.addByPrefix('idle', 'char idle', 24, true);
    	charSelectBtn.animation.addByPrefix('selected', 'char selected', 24, true);
		charSelectBtn.animation.play('idle');
    	charSelectBtn.antialiasing = ClientPrefs.data.antialiasing;
    	freeplayUIGrp.add(charSelectBtn);

		startButton = new FlxSprite(100, 0); // freeplayUIGrp 기준 상대좌표
    	startButton.frames = Paths.getSparrowAtlas('freeplayUI/battleStart');
    	startButton.animation.addByPrefix('idle', 'start idle', 24, true);
    	startButton.animation.addByPrefix('selected', 'start selected', 24, true);
		startButton.animation.play('idle');
    	startButton.antialiasing = ClientPrefs.data.antialiasing;
		startButton.scale.set(0.6, 0.6);
		startButton.updateHitbox();
    	freeplayUIGrp.add(startButton);

		refreshDiffButtons(); // diffButtons는 내부에서 freeplayUIGrp에 추가됨 (startButton 생성 후로 이동)

		energyBox = new FlxSprite(0,0).loadGraphic(Paths.image('freeplayUI/energyBox'));
		energyBox.scale.set(0.6,0.6);
		energyBox.updateHitbox();
		freeplayUIGrp.add(energyBox);
		energyBox.x = startButton.x;
		energyBox.y = startButton.y - energyBox.height - 5;
		startButton.antialiasing = ClientPrefs.data.antialiasing;
		
		
		energyTxt = new FlxText(0, 0, 0,Std.string(EnergySystem.currentEnergy) ,48,true);
		energyTxt.setFormat(Paths.font("pixel-latin.ttf"), 17, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		energyTxt.borderSize = 1.5;
		freeplayUIGrp.add(energyTxt);
		energyTxt.x = startButton.x + startButton.width - energyTxt.width - 50;
		energyTxt.y = startButton.y - energyTxt.height - 12;
		
		lsTxt = new FlxText(0, 0, 0,Std.string(EnergySystem.leaderShip) ,48,true);
		lsTxt.setFormat(Paths.font("pixel-latin.ttf"), 15, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		lsTxt.borderSize = 1.5;
		freeplayUIGrp.add(lsTxt);
		lsTxt.x = startButton.x + startButton.width - lsTxt.width - lsTxt.width / 2 - 2;
		lsTxt.y = energyBox.y;
		
		add(freeplayUIGrp);
		
		if(curSelected >= songs.length) curSelected = 0;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));
		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);
		
		var leText:String = Language.getPhrase("freeplay_tip", "스페이스 / 엔터를 눌러 곡 플레이! 위, 아래로 내려서 곡 선택 가능! 재밌게 플레이해보자! 기록을 갱신해보자!");
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);
		
		player = new MusicPlayer(this);
		add(player);
		
		changeSelection();
		updateTexts();
		FlxG.mouse.visible = true;
		super.create();

	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	override function update(elapsed:Float)
	{
		Conductor.songPosition = FlxG.sound.music.time;
		for (btn in diffButtons) {
    		if (FlxG.mouse.overlaps(btn) && FlxG.mouse.justPressed) {
        		changeDiff(btn.ID - curDifficulty);
        		break;
    		}
		}
		
		if(WeekData.weeksList.length < 1)
			return;
		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2)
			ratingSplit.push('');
		
		while(ratingSplit[1].length < 2)
			ratingSplit[1] += '0';
		var shiftMult:Int = 1;
		if(FlxG.keys.pressed.SHIFT) shiftMult = 3;

		energyTxt.text = Std.string(EnergySystem.currentEnergy);
		lsTxt.text = Std.string(EnergySystem.leaderShip);

		if (EnergySystem.currentEnergy > EnergySystem.maxEnergy) {
    		energyTxt.color = 0xFF04BD20; // Alpha(FF), Red(04), Green(BD), Blue(20)
		} else {
    		energyTxt.color = 0xFFFFFFFF; // 초과 상태가 아닐 때 기본 색상(흰색) 복원
		}
		
		if (FlxG.mouse.overlaps(energyBox) && FlxG.mouse.justPressed) { 
			if (EnergySystem.leaderShip > 0 && EnergySystem.currentEnergy < EnergySystem.maxEnergy) EnergySystem.spendLS(1);
		}
		
		if (FlxG.mouse.overlaps(charSelectBtn)) { 
			if (charSelectBtn.scale.x == 0.6) FlxG.sound.play(Paths.sound('scrollMenu'));
			charSelectBtn.scale.set(0.61, 0.6);
			charSelectBtn.updateHitbox();
			if (charSelectBtn.animation.curAnim.name != 'selected') {
				charSelectBtn.animation.play('selected');
			}
			if (FlxG.mouse.justPressed)
    		{
        		MusicBeatState.switchState(new CharacterSelectState());
    		}
		} else {
			charSelectBtn.scale.set(0.6, 0.6);
			charSelectBtn.updateHitbox();
			charSelectBtn.animation.play('idle');
		}
		
		
		
		if (FlxG.mouse.overlaps(startButton)) { 
			if (startButton.scale.x == 0.6) FlxG.sound.play(Paths.sound('scrollMenu'));
			startButton.scale.set(0.61, 0.6);
			startButton.updateHitbox();
			if (startButton.animation.curAnim.name != 'selected') {
				startButton.animation.play('selected');
			}
			if (FlxG.mouse.justPressed) {
				persistentUpdate = false;
				var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
				var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
			
				var energyData:Dynamic = haxe.Json.parse(Paths.getTextFromFile('data/energy.json'));
				var value:Dynamic = Reflect.field(energyData, poop);
				if (value != null) {
					if (EnergySystem.canSpend(Std.int(value))) {
						MusicBeatState.getVariables().set('energyCost', Std.int(value));
						states.PlayState.pendingEnergyCost = Std.int(value);
					}
					else {
						openSubState(new substates.ErrorSubstate(Language.getPhrase("no_energy", "No Energy!")));
						return;
					}
				}
				
				try {
					Song.loadFromJson(poop, songLowercase);
					PlayState.isStoryMode = false;
					PlayState.storyDifficulty = curDifficulty;

					trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
				}
				catch(e:haxe.Exception)
				{
					trace('ERROR! ${e.message}');
					var errorStr:String = e.message;
					if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1);
					else errorStr += '\n\n' + e.stack;

					missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
					missingText.screenCenter(Y);
					missingText.visible = true;
					missingTextBG.visible = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));

					updateTexts(elapsed);
					super.update(elapsed);
					return;
				}

				@:privateAccess
				if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
				{
					trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
					Paths.freeGraphicsFromMemory();
				}
				LoadingState.prepareToSong();
				LoadingState.loadAndSwitchState(new PlayState());
				#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop();
				#end
				stopMusicPlay = true;

				destroyFreeplayVocals();
				#if (MODS_ALLOWED && DISCORD_ALLOWED)
				DiscordClient.loadModRPC();
				#end
			}
			
		} else {
			startButton.scale.set(0.6, 0.6);
			startButton.updateHitbox();
			startButton.animation.play('idle');
		}





		
		if (!player.playingMusic)
		{
			scoreText.text = '내 최고점수 : ' + lerpScore + '\n정확도: ' + ratingSplit.join('.') + '%'+'\n미스: '+misses;
			positionHighscore();
			
			if(songs.length > 0)
			{
				if (FlxG.keys.justPressed.INSERT) {
					EnergySystem.currentEnergy += 10;
				}
				if(FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;	
				}
				else if(FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;
				}
				if (controls.UI_LEFT_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_RIGHT_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}
				if(FlxG.keys.checkStatus(flixel.input.keyboard.FlxKey.TAB, JUST_PRESSED))
				{
					FlxG.sound.play(Paths.sound('scrollMenu'));
    				MusicBeatState.switchState(new CharacterSelectState());
				}

				if(controls.UI_LEFT || controls.UI_RIGHT)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_LEFT ? -shiftMult : shiftMult));
				}
				else
					holdTime = 0;

				if(FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else 
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if(FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
// 		else if(FlxG.keys.justPressed.SPACE)
// 		{
// 			if(instPlaying != curSelected && !player.playingMusic)
// 			{
// 				destroyFreeplayVocals();
// 				FlxG.sound.music.volume = 0;
// 
// 				Mods.currentModDirectory = songs[curSelected].folder;
// 				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
// 				Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
// 				if (PlayState.SONG.needsVoices)
// 				{
// 					vocals = new FlxSound();
// 					try
// 					{
// 						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
// 						var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
// 						if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song);
// 						
// 						if(loadedVocals != null && loadedVocals.length > 0)
// 						{
// 							vocals.loadEmbedded(loadedVocals);
// 							FlxG.sound.list.add(vocals);
// 							vocals.persist = vocals.looped = true;
// 							vocals.volume = 0.8;
// 							vocals.play();
// 							vocals.pause();
// 						}
// 						else vocals = FlxDestroyUtil.destroy(vocals);
// 					}
// 					catch(e:Dynamic)
// 					{
// 						vocals = FlxDestroyUtil.destroy(vocals);
// 					}
// 					
// 					opponentVocals = new FlxSound();
// 					try
// 					{
// 						var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
// 						var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');
// 						if(loadedVocals != null && loadedVocals.length > 0)
// 						{
// 							opponentVocals.loadEmbedded(loadedVocals);
// 							FlxG.sound.list.add(opponentVocals);
// 							opponentVocals.persist = opponentVocals.looped = true;
// 							opponentVocals.volume = 0.8;
// 							opponentVocals.play();
// 							opponentVocals.pause();
// 						}
// 						else opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
// 					}
// 					catch(e:Dynamic)
// 					{
// 						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
// 					}
// 				}
// 
// 				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
// 				FlxG.sound.music.pause();
// 				instPlaying = curSelected;
// 
// 				player.playingMusic = true;
// 				player.curTime = 0;
// 				player.switchPlayMusic();
// 				player.pauseOrResume(true);
// 			}
// 			else if (instPlaying == curSelected && player.playingMusic)
// 			{
// 				player.pauseOrResume(!player.playing);
// 			}
// 		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			persistentUpdate = false;
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
			
			var energyData:Dynamic = haxe.Json.parse(Paths.getTextFromFile('data/energy.json'));
			var value:Dynamic = Reflect.field(energyData, poop);
			if (value != null) {
				if (EnergySystem.canSpend(Std.int(value))) {
					MusicBeatState.getVariables().set('energyCost', Std.int(value));
					states.PlayState.pendingEnergyCost = Std.int(value);
				}
				else {
					openSubState(new substates.ErrorSubstate(Language.getPhrase("no_energy", "No Energy!")));
					return;
				}
			}
			
			try
			{
				Song.loadFromJson(poop, songLowercase);
				PlayState.isStoryMode = false;
				PlayState.storyDifficulty = curDifficulty;

				trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
			}
			catch(e:haxe.Exception)
			{
				trace('ERROR! ${e.message}');
				var errorStr:String = e.message;
				if(errorStr.contains('There is no TEXT asset with an ID of')) errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length-1);
				else errorStr += '\n\n' + e.stack;

				missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
				missingText.screenCenter(Y);
				missingText.visible = true;
				missingTextBG.visible = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));

				updateTexts(elapsed);
				super.update(elapsed);
				return;
			}

			@:privateAccess
			if(PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
				Paths.freeGraphicsFromMemory();
			}
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop();
			#end
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if(controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}
		
		getEnemyList();
		
		updateTexts(elapsed);
		super.update(elapsed);
	}
	
// 현재 선택된 곡+난이도로 출현 캐릭터 창을 새로 엶
function openEnemyListForCurrent() {
    var songName:String = Paths.formatToSongPath(songs[curSelected].songName);
    var diffName:String = Paths.formatToSongPath(Difficulty.list[curDifficulty]);
    var json = new EasyJson(Paths.getPath('data/enemyList.json', TEXT));
    var value:Array<String> = json.get('$songName-$diffName');
    if (value == null) return;

    currentEnemyList = new EnemyList(value);
    add(currentEnemyList);
}

// 열려있는 출현 캐릭터 창이 있으면 닫음
function closeEnemyListIfOpen() {
    if (currentEnemyList != null && !currentEnemyList.closed) {
        currentEnemyList.close();
    }
    currentEnemyList = null;
}

// 곡/난이도가 바뀌었을 때, 창이 열려있었다면 새 곡 기준으로 갈아끼움
function refreshEnemyListOnChange() {
    if (currentEnemyList != null && !currentEnemyList.closed) {
        closeEnemyListIfOpen();
        openEnemyListForCurrent();
    }
}

function getEnemyList() {
    var item = grpSongs.members[curSelected];
    if (item == null) return;
    if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(item)) {
        closeEnemyListIfOpen();
        openEnemyListForCurrent();
    }
}



	
	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(vocals != null) vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if(opponentVocals != null) opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;
		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length-1);
		misses = Highscore.getMisses(songs[curSelected].songName, curDifficulty);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();
		
		var songName:String = Paths.formatToSongPath(songs[curSelected].songName);
		var diffName:String = Paths.formatToSongPath(Difficulty.list[curDifficulty]);

		for (i in 0...songs.length)
		{
			var item = grpSongs.members[i];
			if (item == null) continue;
			Mods.currentModDirectory = songs[i].folder;
			var songName:String = Paths.formatToSongPath(songs[i].songName);
			var imgPath:String = 'freeplay/' + songName + '-' + diffName;
			if (Paths.fileExists(('images/' + imgPath + '.png'), IMAGE)) {
				item.loadGraphic(Paths.image(imgPath));
			}
			else {
				var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[songs[i].week]);
				var baseDiff:String = 'normal';
				if (leWeek != null && leWeek.difficulties != null && leWeek.difficulties.trim() != '') {
					baseDiff = leWeek.difficulties.split(',')[0].trim();
				}
				
				var baseDiffName:String = Paths.formatToSongPath(baseDiff);
				var fallbackPath:String = 'freeplay/' + songName + '-' + baseDiffName;
				if (Paths.fileExists(('images/' + fallbackPath + '.png'), IMAGE)) {
					item.loadGraphic(Paths.image(fallbackPath));
				} 
				else {
					var normalPath:String = 'freeplay/' + songName + '-normal';
					if (Paths.fileExists(('images/' + normalPath + '.png'), IMAGE)) {
						item.loadGraphic(Paths.image(normalPath));
					}
					else if (Paths.fileExists(('images/freeplay/' + songName + '.png'), IMAGE)) {
						item.loadGraphic(Paths.image('freeplay/' + songName));
					}
					else {
						item.makeGraphic(1, 1, 0x00000000);
					}
				}
			}
			item.setGraphicSize(0, 120);
			item.updateHitbox();
		}
		
		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
		refreshDiffButtons();
		refreshEnemyListOnChange();
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length-1);
		_updateSongLastDifficulty();
		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
		for (num => item in grpSongs.members)
		{
			item.alpha = 0.6;
			if (item.ID == curSelected)
			{
				item.alpha = 1;
			}
		}
		
		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();
		
		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if(savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if(lastDiff > -1)
			curDifficulty = lastDiff;
		else if(Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	private function positionHighscore()
	{
		scoreText.x = 150;
		scoreText.y = 90; // 이미지 y(20) + 이미지 높이(120) + 여백(10)

		scoreBG.scale.x = FlxG.width + 12;
		scoreBG.x = -6;
		scoreBG.y = scoreText.y - 4;
		scoreBG.scale.y = scoreText.height + 8;
		scoreBG.updateHitbox();

		diffText.screenCenter(X);
		diffText.y = scoreText.y - 100;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			var item:FlxSprite = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = FlxG.width / 2 + (item.ID - lerpSelected) * (item.width + 30) - item.width / 2;
			item.y = 80;
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
	override function beatHit() {
    	super.beatHit();
    	if (currentEnemyList != null && !currentEnemyList.closed) {
        	currentEnemyList.beatHit();
    	}
	}

}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;
	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}
