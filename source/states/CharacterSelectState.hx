package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import haxe.Json;
import openfl.utils.Assets;

class CharacterSelectState extends MusicBeatState
{
    public static var selectedSongGroup:String = "bf_songs";

    var charData:Map<String, Array<String>> = new Map<String, Array<String>>();
    var charList:Array<String> = [];
    var curSelected:Int = 0;
    var isTransitioning:Bool = false;

    // 화면 요소
    var bg:FlxSprite;
    var charSprite:FlxSprite;
    var nameSprite:FlxSprite;
    var leftArrow:FlxSprite;
    var rightArrow:FlxSprite;

    override function create()
    {
        FlxG.mouse.visible = true;
        // 1. 배경
        bg = new FlxSprite().loadGraphic(Paths.image('charSelectBG'));
        add(bg);

        // 2. 캐릭터 스프라이트
        charSprite = new FlxSprite();
        add(charSprite);

        // 3. 이름 이미지 스프라이트
        nameSprite = new FlxSprite(0, 300);
        add(nameSprite);

        // 4. 왼쪽 화살표 (스패로우 시트)
        leftArrow = new FlxSprite(100, 0);
        leftArrow.frames = Paths.getSparrowAtlas('charSelect/arrowLeft');
        leftArrow.animation.addByPrefix('idle', 'idle', 24, true);
        leftArrow.animation.addByPrefix('select', 'select', 24, true); // 누르는 동안 무한 반복
        leftArrow.animation.play('idle');
        leftArrow.screenCenter(Y);
        add(leftArrow);

        // 5. 오른쪽 화살표 (스패로우 시트)
        rightArrow = new FlxSprite(FlxG.width - 200, 0);
        rightArrow.frames = Paths.getSparrowAtlas('charSelect/arrowRight');
        rightArrow.animation.addByPrefix('idle', 'idle', 24, true);
        rightArrow.animation.addByPrefix('select', 'select', 24, true); // 무한 반복
        rightArrow.animation.play('idle');
        rightArrow.screenCenter(Y);
        add(rightArrow);

        loadCharacterJson();
        changeSelection(0);

        super.create();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        if (isTransitioning) return;

        // Psych Engine controls 시스템 적용 (누르고 있으면 select 재생, 떼면 idle)
        if (controls.UI_LEFT) {
            leftArrow.animation.play('select');
        } else {
            leftArrow.animation.play('idle');
        }

        if (controls.UI_RIGHT) {
            rightArrow.animation.play('select');
        } else {
            rightArrow.animation.play('idle');
        }

        // 입력 시 1회 선택 변경
        if (controls.UI_LEFT_P) {
            changeSelection(-1);
        }
        if (controls.UI_RIGHT_P) {
            changeSelection(1);
        }

        if (controls.ACCEPT) selectCharacter();
        if (controls.BACK) MusicBeatState.switchState(new MainMenuState());
    }

    function loadCharacterJson()
    {
        var path:String = Paths.modsJson('characterSelect');
    
        if (sys.FileSystem.exists(path)) {
            var rawJson:String = sys.io.File.getContent(path).trim();
        
            if (rawJson.startsWith('{') && rawJson.endsWith('}')) {
                var parsed:Dynamic = Json.parse(rawJson);
                for (field in Reflect.fields(parsed)) {
                    var dataArray:Array<Dynamic> = Reflect.field(parsed, field);
                    var stringArray:Array<String> = [];
                    for (item in dataArray) {
                        stringArray.push(Std.string(item));
                    }
                
                    charData.set(field, stringArray);
                    charList.push(field);
                }
            } else {
                trace("JSON 형식이 올바르지 않습니다. 중괄호 세팅을 확인하세요.");
            }
        } else {
            trace("JSON 파일을 찾을 수 없습니다: " + path);
        }
    }

    function changeSelection(change:Int = 0)
    {
        curSelected += (change % charList.length + charList.length) % charList.length;
        curSelected %= charList.length;

        FlxG.sound.play(Paths.sound('scrollMenu'));

        var name:String = charList[curSelected];
        var data:Array<String> = charData.get(name);

        bg.loadGraphic(Paths.image(data[1])); 

        charSprite.loadGraphic(Paths.image('charSelect/' + name));
        charSprite.screenCenter(X);
        charSprite.y = bg.y + (bg.height * 1 / 4) - (charSprite.height / 2);
        
        nameSprite.loadGraphic(Paths.image('charNames/' + name));
        nameSprite.y = bg.y + (bg.height * 3 / 4) - (charSprite.height / 2);
        nameSprite.screenCenter(X);
    }

    function selectCharacter()
    {
        isTransitioning = true;
        var name:String = charList[curSelected];
    
        var data:Array<String> = charData.get(name);
        if (data != null && data.length > 0) {
            FlxG.save.data.selectedSongGroup = data[0];
            FlxG.save.flush();
        }
    
        FlxG.sound.play(Paths.sound('charSelect/' + name));
        charSprite.loadGraphic(Paths.image('charSelect/' + name + 'go'));
        charSprite.screenCenter(X); // Y는 changeSelection()과 같은 공식 유지 (전체중앙정렬 시 위치 튐 방지)
        charSprite.y = bg.y + (bg.height * 1 / 4) - (charSprite.height / 2);

        backend.WeekData.weeksList = [];
        backend.WeekData.weeksLoaded.clear();

        new FlxTimer().start(1.5, function(tmr:FlxTimer) {
            MusicBeatState.switchState(new FreeplayState());
        });
    }
}
