import haxe.io.Path;
import haxe.macro.Expr;
import haxe.macro.Printer;
import js.lib.Error;
import js.lib.Promise;
import sys.FileSystem;
import tink.core.Future;
import tink.core.Named;
import tink.core.Promise as TinkPromise;

@:jsRequire("selenium-webdriver")
extern class WebDriverApi {
	static final until:WebDriverUntil;
}

extern class WebDriverUntil {
	function elementLocated(by:By):WebElementCondition;
}

extern class WebElementCondition {}

@:jsRequire("selenium-webdriver", "Builder")
extern class Builder {
	function new();
	function forBrowser(browser:String):Builder;
	function build():ThenableWebDriver;
}

@:jsRequire("selenium-webdriver", "By")
extern class By {
	static function className(name:String):By;
	static function css(selector:String):By;
	static function id(id:String):By;
	static function name(name:String):By;
}

extern interface IWebDriver {
	function get(url:String):Promise<Void>;
	function close():Promise<Void>;
	function wait(condition:WebElementCondition):Promise<WebElement>;
}


extern class WebElement {
	function getAttribute(attributeName:String):Promise<Null<String>>;
}

extern interface ThenableWebDriver {
	function then(onFulfilled:IWebDriver->Void, ?onRejected:Error->Void):Void;
}

typedef Edges = {start:Dim, end:Dim, top:Dim, bottom:Dim};
typedef Dim = {unit:String, value:Null<Float>};
typedef Size = {width:Dim, height:Dim};
typedef Desc = {
	var style:{
		var display:String;
		var position_type:String;
		var direction:String;
		var flexDirection:String;
		var flexWrap:String;
		var overflow:String;
		var alignItems:String;
		var alignSelf:String;
		var alignContent:String;
		var justifyContent:String;
		var flexGrow:Float;
		var flexShrink:Float;
		var flexBasis:Dim;
		var size:Size;
		var min_size:Size;
		var max_size:Size;
		var margin:Edges;
		var padding:Edges;
		var border:Edges;
		var position:Edges;
	};
	var layout:{
		var width:Float;
		var height:Float;
		var x:Float;
		var y:Float;
	};
	var children:Array<Desc>;
}

function getDescriptions():Future<Array<Named<Desc>>> {
	var paths = [
		for (name in sys.FileSystem.readDirectory("test_fixtures"))
			if (Path.extension(name) == "html")
				FileSystem.fullPath("test_fixtures/"+name)
	];
	var trigger = Future.trigger();
	new Builder().forBrowser("chrome").build().then(d -> {
		var locator = By.css("#test-root");
		function getData(path) {
			return new TinkPromise((resolve,reject) -> {
				var name = new Path(path).file;
				d.get("file://"+path)
					.then(_ -> d.wait(WebDriverApi.until.elementLocated(locator)))
					.then(e -> e.getAttribute("__stretch_description__"))
					.then(json -> resolve(new Named(name, haxe.Json.parse(json))), e -> tink.core.Error.ofJsError(e))
				;
				return null;
			});
		}
		TinkPromise.inSequence(paths.map(getData)).handle(outcome -> {
			d.close();
			trigger.trigger(outcome.sure());
		});
	});
	return trigger;
}

function main() {
	getDescriptions().handle(descrs -> {
		var fields = new Array<Field>();
		for (o in descrs) {
			var d = o.value;

			var exprs:Array<Expr> = [];

			function genNode(name:String, node:Desc) {
				var style = node.style;
				var styleFields = new Array<ObjectField>();
				inline function add(name:String, e:Expr) {
					styleFields.push({field: name, expr: e});
				}

				if (style.display == "none") add("display", macro None);
				if (style.position_type == "absolute") add("positionType", macro Absolute);
				switch style.direction {
					case "rtl": add("direction", macro RTL);
					case "ltr": add("direction", macro LTR);
				}
				switch style.flexDirection {
					case "row-reverse": add("flexDirection", macro RowReverse);
					case "column": add("flexDirection", macro Column);
					case "column-reverse": add("flexDirection", macro ColumnReverse);
				}
				switch style.flexWrap {
					case "wrap": add("flexWrap", macro Wrap);
					case "wrap-reverse": add("flexWrap", macro WrapReverse);
				}
				switch style.overflow {
					case "hidden": add("overflow", macro Hidden);
					case "scroll": add("overflow", macro Scroll);
				}
				switch style.alignItems {
					case "flex-start": add("alignItems", macro FlexStart);
					case "flex-end": add("alignItems", macro FlexEnd);
					case "center": add("alignItems", macro Center);
					case "baseline": add("alignItems", macro Baseline);
				}
				switch style.alignSelf {
					case "flex-start": add("alignSelf", macro FlexStart);
					case "flex-end": add("alignSelf", macro FlexEnd);
					case "center": add("alignSelf", macro Center);
					case "baseline": add("alignSelf", macro Baseline);
					case "stretch": add("alignSelf", macro Stretch);
				}
				switch style.alignContent {
					case "flex-start": add("alignContent", macro FlexStart);
					case "flex-end": add("alignContent", macro FlexEnd);
					case "center": add("alignContent", macro Center);
					case "space-between": add("alignContent", macro SpaceBetween);
					case "space-around": add("alignContent", macro SpaceAround);
				}
				switch style.justifyContent {
					case "flex-end": add("justifyContent", macro FlexEnd);
					case "center": add("justifyContent", macro Center);
					case "space-between": add("justifyContent", macro SpaceBetween);
					case "space-around": add("justifyContent", macro SpaceAround);
					case "space-evenly": add("justifyContent", macro SpaceEvenly);
				}

				function mkFloat(f:Float):Expr return {pos: null, expr: EConst(CFloat(Std.string(f)))};
				function mkDim(d:Dim):Expr return
					if (d == null) macro Auto
					else switch d.unit {
						case "auto": macro Auto;
						case "points": macro Points(${mkFloat(d.value)});
						case "percent": macro Percent(${mkFloat(d.value)});
						case _: throw "invalid";
					};
				function mkSize(d:Size):Expr return macro {
					width: ${mkDim(d.width)},
					height: ${mkDim(d.height)},
				};

				if (style.flexGrow != null) add("flexGrow", mkFloat(style.flexGrow));
				if (style.flexShrink != null) add("flexShrink", mkFloat(style.flexShrink));
				if (style.flexBasis != null) add("flexBasis", mkDim(style.flexBasis));
				if (style.size != null) add("size", mkSize(style.size));
				if (style.min_size != null) add("minSize", mkSize(style.min_size));
				if (style.max_size != null) add("maxSize", mkSize(style.max_size));

				function mkEdges(e:Edges) return macro {
					start: ${mkDim(e.start)},
					end: ${mkDim(e.end)},
					top: ${mkDim(e.top)},
					bottom: ${mkDim(e.bottom)},
				}

				if (style.margin != null) add("margin", mkEdges(style.margin));
				if (style.padding != null) add("padding", mkEdges(style.padding));
				if (style.position != null) add("position", mkEdges(style.position));
				if (style.border != null) add("border", mkEdges(style.border));

				var childIdents = new Array<Expr>();
				for (i => child in node.children) {
					var childName = name + i;
					genNode(childName, child);
					childIdents.push(macro $i{childName});
				}

				exprs.push(macro var $name = new Node(
					${{pos: null, expr: EObjectDecl(styleFields)}},
					$a{childIdents}
				));
			}

			function eq(e:Expr, v:Float) {
				var ve = {pos: null, expr: EConst(CFloat(Std.string(v)))}; // $v{} doesn't work outside macros :(
				exprs.push(macro Assert.equals($ve, $e));
			}

			function genAsserts(name:String, node:Desc) {
				eq(macro $i{name}.layout.size.width, node.layout.width);
				eq(macro $i{name}.layout.size.height, node.layout.height);
				eq(macro $i{name}.layout.location.x, node.layout.x);
				eq(macro $i{name}.layout.location.y, node.layout.y);
				for (i => child in node.children) genAsserts(name + i, child);
			}

			genNode("node", d);
			exprs.push(macro Stretch.computeLayout(node, Size.undefined()));
			genAsserts("node", d);

			fields.push({
				pos: null,
				name: "test_" + o.name,
				kind: FFun({
					args: [],
					ret: null,
					expr: macro $b{exprs}
				})
			});
		}
		var td:TypeDefinition = {
			pack: [],
			name: "TestFixtures",
			pos: null,
			kind: TDClass({pack: ["utest"], name: "Test"}),
			fields: fields
		}
		var hx = new Printer().printTypeDefinition(td);
		hx = "// this file is autogenerated with GenTest.hx\n" + hx;
		sys.io.File.saveContent("test/TestFixtures.hx", hx);
	});
}
