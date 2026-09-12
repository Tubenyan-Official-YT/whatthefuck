package backend;

class Adventure
{
	public var name:String;          // 모험 지역명
	public var time:Float;           // 걸리는시간(초)
	public var completed:Bool = false; // 끝났는가
	public var isLocked:Bool = true;//잠겼는가

	public function new(name:String, time:Float)
	{
		this.name = name;
		this.time = time;
	}
}
