package backend;

import flixel.util.FlxSave;
#if LUA_ALLOWED
import psychlua.FunkinLua;
#end
#if (MODS_ALLOWED || sys)
import sys.FileSystem;
#end

class Gamatoto
{
	public static var curAd:Adventure;
	public static var startTime:Float = 0;

	// 언락된 모험 이름 목록. 기본값은 첫 모험만 (init()에서 비어있으면 채움)
	public static var unlockedNames:Array<String> = [];

	static var sv:FlxSave;
	#if LUA_ALLOWED
	static var gamatotoLua:FunkinLua;
	#end

	// 1. 시작할 때 (게임 켤 때 호출)
	public static function init():Void
	{
		load();

		// 1-1. 현재 어드벤처를 구하고
		if (curAd == null) return; // 진행중인 모험 없음

		var elapsed = Clock.elapsedSince(startTime);

		// 1-2. 만약 elapsed > 현재 모험의 걸리는시간
		if (elapsed > curAd.time)
		{
			// 1-2-1. 모험이 끝났다고 하기
			curAd.completed = true;
		}
		// 1-3. else: 아직 진행중. 남은시간은 getRemaining()으로 그때그때 계산
	}

	// 새 모험 시작
	public static function startAdventure(ad:Adventure):Void
	{
		curAd = ad;
		curAd.completed = false;
		startTime = Clock.now();
		save();
	}

	public static function isUnlocked(name:String):Bool
	{
		return unlockedNames.indexOf(name) != -1;
	}

	// Lua에서 unlockGamatoto(name) 함수로 호출됨
	public static function unlock(name:String):Void
	{
		if (!isUnlocked(name))
		{
			unlockedNames.push(name);
			save();
		}
	}

	// 남은시간(초). 완료됐으면 0
	public static function getRemaining():Float
	{
		if (curAd == null) return 0;
		return Clock.remaining(startTime, curAd.time);
	}

	// 보상 수령: 실제 보상 지급은 Lua의 onAdventureEnd(name)에서 모드측이 직접 처리
	public static function claim():Void
	{
		if (curAd == null || !curAd.completed) return;

		#if LUA_ALLOWED
		callAdventureEndLua(curAd.name);
		#end

		curAd = null;
		save();
	}

	#if LUA_ALLOWED
	static function callAdventureEndLua(name:String):Void
	{
		if (gamatotoLua == null)
		{
			var luaFile:String = 'data/gamatoto/gamatoto.lua';
			#if MODS_ALLOWED
			var luaToLoad:String = Paths.modFolders(luaFile);
			if (!FileSystem.exists(luaToLoad))
				luaToLoad = Paths.getSharedPath(luaFile);
			#else
			var luaToLoad:String = Paths.getSharedPath(luaFile);
			#end

			if (FileSystem.exists(luaToLoad))
				gamatotoLua = new FunkinLua(luaToLoad);
		}

		if (gamatotoLua != null)
			gamatotoLua.call('onAdventureEnd', [name]);
	}
	#end

	static function bindSave():Void
	{
		if (sv == null)
		{
			sv = new FlxSave();
			sv.bind('clock');
		}
	}

	static function save():Void
	{
		bindSave();
		sv.data.gamatotoName = curAd != null ? curAd.name : null;
		sv.data.gamatotoTime = curAd != null ? curAd.time : null;
		sv.data.gamatotoStart = startTime;
		sv.data.gamatotoUnlocked = unlockedNames.join(',');
		sv.flush();
	}

	static function load():Void
	{
		bindSave();
		if (sv.data.gamatotoName != null)
		{
			curAd = new Adventure(sv.data.gamatotoName, sv.data.gamatotoTime);
			startTime = sv.data.gamatotoStart;
		}
		if (sv.data.gamatotoUnlocked != null && sv.data.gamatotoUnlocked != '')
			unlockedNames = sv.data.gamatotoUnlocked.split(',');
	}
}
