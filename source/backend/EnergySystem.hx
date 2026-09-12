package backend;

import flixel.FlxG;

class EnergySystem
{
    // 통솔력 기본 설정
    public static var maxEnergy:Int = 100;
    public static var addEnergy:Int = 5;
    public static var currentEnergy:Int = 100;
    public static var givingSec:Float = 300;
    public static var lastSaveTime:Float = 0;

    public static var leaderShip:Int = 0;
    private static var timer:Float = 0;

    public static function init():Void
    {
        load();
        calculateEnergy(); // 접속 시 미정산 회복량 즉시 정산

        // 이벤트 신호 등록
        FlxG.signals.postUpdate.add(function() update(FlxG.elapsed));
        FlxG.signals.focusGained.add(function() {
            load();
            calculateEnergy();
        });
        FlxG.signals.focusLost.add(save);
    }

    public static function calculateEnergy():Void
    {
        if (currentEnergy >= maxEnergy) {
            lastSaveTime = Clock.now();
            return;
        }
        var elapsed = Clock.elapsedSince(lastSaveTime);
        if (elapsed < givingSec) return;

        var cycles:Int = Clock.getCycles(elapsed, givingSec);

        currentEnergy += cycles * addEnergy;
        if (currentEnergy > maxEnergy) currentEnergy = maxEnergy; // 최대치 제한

        lastSaveTime += cycles * givingSec;
        save();
    }

    public static function load():Void
    {
        // 세이브 데이터가 준비되지 않았으면 로드를 진행하지 않음
        if (FlxG.save == null || FlxG.save.data == null) return;

        if (FlxG.save.data.maxEnergy != null) maxEnergy = FlxG.save.data.maxEnergy;
        if (FlxG.save.data.addEnergy != null) addEnergy = FlxG.save.data.addEnergy;
        if (FlxG.save.data.currentEnergy != null) currentEnergy = FlxG.save.data.currentEnergy;
        if (FlxG.save.data.givingSec != null) givingSec = FlxG.save.data.givingSec;

        if (FlxG.save.data.leaderShip != null) leaderShip = FlxG.save.data.leaderShip;

        if (FlxG.save.data.lastSaveTime != null) lastSaveTime = FlxG.save.data.lastSaveTime;
        else lastSaveTime = Clock.now();
    }

    public static function save():Void
    {
        if (FlxG.save == null || FlxG.save.data == null) return;

        FlxG.save.data.maxEnergy = maxEnergy;
        FlxG.save.data.addEnergy = addEnergy;
        FlxG.save.data.currentEnergy = currentEnergy;
        FlxG.save.data.givingSec = givingSec;
        FlxG.save.data.lastSaveTime = lastSaveTime;
        FlxG.save.data.leaderShip = leaderShip;
        FlxG.save.flush();
    }

    public static function canSpend(howmuch:Int):Bool {
        if (howmuch > currentEnergy) return false;
        else return true;
    }

    public static function spendIt(howmuch:Int):Void {
        if (canSpend(howmuch)) {
            currentEnergy -= howmuch;
            save();
        }
    }

    public static function update(elapsed:Float):Void
    {
        timer += elapsed;
        if (timer >= givingSec) {
            if (currentEnergy < maxEnergy) {
                currentEnergy += addEnergy;
                if (currentEnergy > maxEnergy) currentEnergy = maxEnergy;
            }
            timer = 0;
            lastSaveTime = Clock.now();
            save();
        }
    }

    public static function addLS(howmuch:Int):Void {
        // 리더십추가 (Int 타입 null 검사 제거 및 인자값 반영)
        leaderShip += howmuch;
        save();
    }
    public static function spendLS(howmuch:Int):Void {
        // 리더십빼기, 통솔력 추가하기 (Int 타입 null 검사 제거 및 인자값 반영)
        if (leaderShip > 0) leaderShip -= howmuch; currentEnergy += howmuch * maxEnergy;
        save();
    }
    public static function addMaxEnergy(howmuch:Int):Void {
        maxEnergy += howmuch;
        save();
    }
    public static function addcurEnergy(howmuch:Int):Void {
        currentEnergy += howmuch;
        if (currentEnergy >= maxEnergy) currentEnergy = maxEnergy;
        save();
    }
}
