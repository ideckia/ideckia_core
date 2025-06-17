package;

@:jsRequire('qrcode')
extern class QrCode {
	static function toFile(path:String, text:String, options:Dynamic, errorFunction:Dynamic->Void):Void;
}
