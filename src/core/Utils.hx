package;

import api.IdeckiaApi.IdeckiaAction;

class Utils {
	static inline public function hasJsFunction(action:IdeckiaAction, funcName:String) {
		return js.Syntax.code("typeof {0}", js.Syntax.field(action, funcName)) == 'function';
	}
}
