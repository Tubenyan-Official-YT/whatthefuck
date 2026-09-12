package backend;

import flixel.FlxG;
import flixel.util.FlxSave;
import lime.app.Application;

/**
 * 백그라운드(오프라인) 경과 시간 계산용 공용 유틸리티.
 * 원래 통솔력(EnergySystem)에만 있던 실시간 계산 로직을 분리해서
 * 다른 시스템(가마토토 탐험 등)에서도 재사용할 수 있게 만듦.
 *
 * 게임이 꺼질 때 현재 시각을 clock.sol에 저장하고,
 * 다음에 켜질 때 그 값을 불러와서 꺼져있던 동안 흐른 시간을 elapsed에 저장함.
 */
class Clock
{
	// 게임이 꺼져있던 동안(백그라운드) 흐른 시간(초). init() 호출 시 1회 계산됨.
	public static var elapsed:Float = 0;

	private static var clockSave:FlxSave;
	private static var initialized:Bool = false;

	public static function init():Void
	{
		if (initialized) return;
		initialized = true;

		clockSave = new FlxSave();
		clockSave.bind('clock'); // clock.sol

		if (clockSave.data.lastCloseTime != null)
			elapsed = elapsedSince(clockSave.data.lastCloseTime);
		else
			elapsed = 0;

		// 창이 닫힐 때 현재 시각 저장 (실제 종료 시점)
		Application.current.window.onClose.add(saveCloseTime);
		// 혹시 onClose가 안 불리는 환경 대비 안전장치 (포커스 잃을 때도 갱신)
		FlxG.signals.focusLost.add(saveCloseTime);
	}

	private static function saveCloseTime():Void
	{
		if (clockSave == null) return;
		clockSave.data.lastCloseTime = now();
		clockSave.flush();
	}

	// 현재 시각 (유닉스 타임, 초 단위)
	public static function now():Float
	{
		return Date.now().getTime() / 1000;
	}

	// pastTime(초) 기준으로 지금까지 흐른 시간(초)
	public static function elapsedSince(pastTime:Float):Float
	{
		return now() - pastTime;
	}

	// interval(초) 단위로 몇 번의 주기가 지났는지 (통솔력 회복처럼 반복형 회복에 사용)
	public static function getCycles(elapsed:Float, interval:Float):Int
	{
		if (interval <= 0) return 0;
		return Std.int(elapsed / interval);
	}

	// startTime부터 duration(초)이 다 지났는지 (가마토토 탐험처럼 1회성 타이머에 사용)
	public static function isElapsed(startTime:Float, duration:Float):Bool
	{
		return elapsedSince(startTime) >= duration;
	}

	// startTime부터 duration(초) 중 남은 시간(초). 이미 다 지났으면 0
	public static function remaining(startTime:Float, duration:Float):Float
	{
		var left = duration - elapsedSince(startTime);
		return left > 0 ? left : 0;
	}
}
