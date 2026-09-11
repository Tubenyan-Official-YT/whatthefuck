package;

import flixel.tweens.FlxTween;
import flixel.tweens.TweenOptions;

class Tween
{
    public static function new(Object:Dynamic, Values:Dynamic, Duration:Float = 1, ?Options:TweenOptions):FlxTween {
        FlxTween.cancelTweensOf(Object);
        return FlxTween.tween(Object, Values, Duration, Options);
    }
}
