using Common;

typedef K = flash.ui.Keyboard;

class Game implements haxe.Public {
	
	var root : SPR;
	var view : SPR;
	var world : World;
	var scroll : { x : Float, y : Float, mc : SPR, curZ : Float, tz : Float };
	var hero : Hero;
	var output : BMP;
	var pixelFilter : BMP;
	var dm : DepthManager;
	
	var barsDelta : Float;
	var curColor : { mask : Float, delta : Float, alpha : Float, rgb : Float, k : Float };
	var shake : { time : Float, power : Float };
	
	public static var props = {
		debug : true,
		zoom : 2, // 4,
		bars : false, // true,
		left : true, // false,
		scroll : 2, // 0,
		color : 4, // 0,
		life : 0,
		monsters : 0,
	};
	
	function new(root) {
		this.root = root;
	}
	
	function init() {
		view = new SPR();
		barsDelta = 0.;
		output = new BMP(root.stage.stageWidth, root.stage.stageHeight);
		root.addChild(new flash.display.Bitmap(output));
		
		initPixelFilter(props.zoom);
		
		world = new World();
		world.draw();
		scroll = { x : (world.start.x + 0.5) * Const.SIZE, y : (world.start.y + 0.5) * Const.SIZE, mc : new SPR(), curZ : props.zoom, tz : 1. };
		scroll.mc.x = -1000;
		scroll.mc.addChild(new flash.display.Bitmap(world.bmp));
		dm = new DepthManager(scroll.mc);
		view.addChild(scroll.mc);
		
		for( c in world.chests ) {
			c.e = new Entity(Chest,c.x,c.y);
			c.e.update(0);
		}

		hero = new Hero(world.start.x, world.start.y);
		
		update();
		root.addEventListener(flash.events.Event.ENTER_FRAME, function(_) update());
		
		getChest(CRightCtrl);
	}
	
	function js( s : String ) {
		if( !flash.external.ExternalInterface.available )
			return;
		flash.external.ExternalInterface.call("eval", s);
	}
	
	function popup( text : String, subText : String = "" ) {
		var mc = new Popup();
		mc.addChild(makePanel(text, subText));
		mc.y = output.height;
		mc.targetY = output.height - mc.height;
		root.addChild(mc);
	}
	
	function makePanel( text : String, subText : String ) {
		var mc = new SPR();
		mc.graphics.beginFill(0);
		mc.graphics.drawRect(0, 0, output.width, 40);
		var tf = makeField(text);
		tf.x = tf.y = 3;
		mc.addChild(tf);
		var tf = makeField(subText, 14);
		tf.x = 3;
		tf.y = 22;
		mc.addChild(tf);
		return mc;
	}
	
	function makeField(text,size=20) {
		var tf = new TF();
		var fmt = tf.defaultTextFormat;
		fmt.font = "BmpFont";
		fmt.size = size;
		fmt.color = 0xFFFFFF;
		tf.defaultTextFormat = fmt;
		tf.embedFonts = true;
		tf.sharpness = 400;
		tf.gridFitType = flash.text.GridFitType.PIXEL;
		tf.antiAliasType = flash.text.AntiAliasType.ADVANCED;
		tf.selectable = tf.mouseEnabled = false;
		tf.autoSize = flash.text.TextFieldAutoSize.LEFT;
		tf.width = 0;
		tf.height = 20;
		tf.htmlText = text;
		return tf;
	}
	
	
	function initPixelFilter( k : Int ) {
		if( pixelFilter != null )
			pixelFilter.fillRect(pixelFilter.rect, 0);
		else
			pixelFilter = new BMP(output.width, output.height, true, 0);
		for( x in 0...Std.int(output.width / k) )
			for( y in 0...Std.int(output.height / k) ) {
				var x = x * k, y = y * k;
				pixelFilter.setPixel32(x, y, 0x40000000);
				for( i in 1...k ) {
					pixelFilter.setPixel32(x + i, y, 0x20000000);
					pixelFilter.setPixel32(x, y + i, 0x20000000);
				}
			}
	}
	
	function doShake() {
		shake = { time : 10, power : 3 };
	}
	
	function getChest( k : Chests.ChestKind ) {
		doShake();
		var index : Null<Int> = null;
		switch( k ) {
		case CTitleScreen, CRightCtrl:
			// no fx
		case CLeftCtrl:
			props.left = true;
		case C2D:
			props.bars = false;
		case CScroll:
			index = props.scroll;
			props.scroll++;
		case CColor:
			index = props.color;
			props.color++;
		case CMonsters:
			index = props.monsters;
			props.monsters++;
			if( props.monsters == 1 )
				for( m in world.monsters )
					m.e = new Monster(m.x, m.y);
		}
		var t : Dynamic = Chests.t[Type.enumIndex(k)];
		if( t == null )
			throw "Missing text for " + k + " (" + Type.enumIndex(k) + ")";
		if( index != null )
			t = t[index];
		popup("You got <font color='#ff0000'>"+t.name+"</font>", t.sub);
	}
	
	function gameOver() {
		hero.lock = true;
		hero.target = null;
		hero.explode();
		hero.remove();
		var mc = makePanel("Game <font color='#ff0000'>Over</font> !", "Press Esc to return to title screen");
		mc.y = Std.int((output.height - mc.height) * 0.5);
		root.addChild(mc);
	}
	
	function update() {
		Timer.update();
		
		switch( props.scroll ) {
		case 0:
			// no
		case 1:
			scroll.x = Std.int(hero.x) * Const.SIZE;
			scroll.y = Std.int(hero.y) * Const.SIZE;
		case 2:
			scroll.x = Std.int(hero.x * Const.SIZE);
			scroll.y = Std.int(hero.y * Const.SIZE);
		default:
		}
		
		var dt = Timer.tmod;
				
		scroll.curZ = scroll.curZ * 0.8 + (scroll.tz * props.zoom) * 0.2;
		var z = scroll.curZ;
		var tx = scroll.x - (root.stage.stageWidth / z) * 0.5;
		var ty = scroll.y - (root.stage.stageHeight / z) * 0.5;
		var sx = Std.int(tx * z);
		var sy = Std.int(ty * z);
		sx -= sx % props.zoom;
		sy -= sy % props.zoom;
		scroll.mc.x = -sx;
		scroll.mc.y = -sy;
		scroll.mc.scaleX = scroll.mc.scaleY = z;
		
		hero.update(dt);
		
		Popup.updateAll(dt);
		Part.updateAll(dt);
		
		if( hero.target == null && !hero.lock ) {
			
			for( c in world.chests )
				if( c.e != null && c.x == hero.ix && c.y == hero.iy ) {
					c.e.remove();
					c.e = null;
					getChest(c.id);
				}
			
			if( (Key.isDown(K.UP) || Key.isDown("Z".code) || Key.isDown("W".code)) && !props.bars && !world.collide(hero.ix, hero.iy - 1) ) {
				hero.iy--;
				hero.target = { x : hero.ix, y : hero.iy };
			}
			if( (Key.isDown(K.DOWN) || Key.isDown("S".code)) && !props.bars && !world.collide(hero.ix, hero.iy+1) ) {
				hero.iy++;
				hero.target = { x : hero.ix, y : hero.iy };
			}
			if( (Key.isDown(K.LEFT) || Key.isDown("Q".code) || Key.isDown("A".code)) && props.left && !world.collide(hero.ix - 1, hero.iy) ) {
				hero.ix--;
				hero.target = { x : hero.ix, y : hero.iy };
			}
			if( (Key.isDown(K.RIGHT) || Key.isDown("D".code)) && !world.collide(hero.ix + 1, hero.iy) ) {
				hero.ix++;
				hero.target = { x : hero.ix, y : hero.iy };
			}
			
			
		}
		
		if( Key.isToggled(27) ) {
			if( !hero.lock )
				gameOver();
			else {
				js("document.location.reload()");
			}
		}

		if( props.debug ) {
			var delta = Key.isToggled(K.NUMPAD_ADD) ? 1 : Key.isToggled(K.NUMPAD_SUBTRACT) ? -1 : 0;
			if( delta != 0 ) {
				if( Key.isDown("C".code) ) {
					doShake();
					props.color += delta;
				}
				if( Key.isDown("S".code) ) {
					doShake();
					props.scroll += delta;
				}
				if( Key.isDown("Z".code) ) {
					props.zoom += delta;
					initPixelFilter(props.zoom);
				}
			}
		}
		
		if( props.monsters > 0 )
			for( m in world.monsters )
				if( m.e != null ) {
					m.e.update(dt);
					var dx = m.e.x - hero.x;
					var dy = m.e.y - hero.y;
					var d = dx * dx + dy * dy;
					if( d < 0.64 ) {
						props.life--;
						if( props.life <= 0 && !hero.lock )
							gameOver();
					}
				}

		var old = curColor;
		var pixelAlpha = 1.0;
		switch( props.color ) {
		case 0:
			curColor = { delta : 0x40, mask : 0xC0, alpha : 1., rgb : 1., k : props.color };
		case 1:
			curColor = { delta : 0x30, mask : 0x80, alpha : 1., rgb : 0., k : props.color };
		case 2:
			curColor = { delta : 0x10, mask : 0xC0, alpha : .5, rgb : 0., k : props.color };
		case 3:
			curColor = { delta : 0x28, mask : 0xE0, alpha : .5, rgb : 0., k : props.color };
		default:
			curColor = { delta : 0, mask : 0xFF, alpha : 0., rgb : 0., k : props.color };
		}
		curColor = if( old == null ) curColor else {
			delta : old.delta * 0.8 + curColor.delta * 0.2,
			mask : old.mask * 0.8 + curColor.mask * 0.2,
			alpha : old.alpha * 0.8 + curColor.alpha * 0.2,
			rgb : old.rgb * 0.8 + curColor.rgb * 0.2,
			k : old.k * 0.8 + curColor.k * 0.2,
		};

		if( shake != null ) {
			var m = new flash.geom.Matrix();
			var a = shake.time < 10 ? shake.time / 10 : 1;
			m.tx = (Math.random() * 2 - 1) * shake.power * a;
			m.ty = (Math.random() * 2 - 1) * shake.power * a;
			output.draw(view, m);
			shake.time -= dt;
			if( shake.time < 0 )
				shake = null;
		} else
			output.draw(view);
		
		var delta = Std.int(curColor.delta);
		var mask = Math.ceil(curColor.mask);
		if( delta != 0 || mask != 0xFF )
			applyMask(delta, mask);

		if( curColor.rgb > 0.01 ) {
			var r = 155;
			var g = 198;
			var b = 15;
			var f = (0.25 / g) * curColor.rgb;
			var k = 1 - curColor.rgb;
			var curFilter = new flash.filters.ColorMatrixFilter([
				k + r*f, r*f, r*f, 0, 20 * curColor.rgb,
				g*f, k + g*f, g*f, 0, 50 * curColor.rgb,
				b*f, b*f, k + b*f, 0, 20 * curColor.rgb,
				0,0,0,1,0,
			]);
			output.applyFilter(output, output.rect, new flash.geom.Point(0, 0), curFilter);
		}
		
		if( curColor.alpha > 0.01 )
			output.draw(pixelFilter,null,new flash.geom.ColorTransform(1,1,1,curColor.alpha));
		
		var size = (Math.ceil(Const.SIZE * scroll.curZ) >> 1) + barsDelta;
		if( props.bars || size < output.height * 0.5  ) {
			output.fillRect(new flash.geom.Rectangle(0, 0, output.width, (output.height >> 1) - size), 0xFF143214);
			output.fillRect(new flash.geom.Rectangle(0, (output.height >> 1) + size, output.width, output.height - (output.height >> 1) + size ), 0xFF143214);
			if( !props.bars )
				barsDelta += 5 * dt;
		}
	}
	
	function applyMask(delta, mask) {
		var bytes = output.getPixels(output.rect);
		flash.Memory.select(bytes);
		var p = 0;
		for( i in 0...output.width * output.height ) {
			var c = flash.Memory.getByte(p) + delta;
			if( c > 0xFF ) c = 0xFF;
			flash.Memory.setByte(p++, c & mask);
			var c = flash.Memory.getByte(p) + delta;
			if( c > 0xFF ) c = 0xFF;
			flash.Memory.setByte(p++, c & mask);
			var c = flash.Memory.getByte(p) + delta;
			if( c > 0xFF ) c = 0xFF;
			flash.Memory.setByte(p++, c & mask);
			p++;
		}
		bytes.position = 0;
		output.setPixels(output.rect,bytes);
	}
	
	public static var inst : Game;
	static function main() {
		inst = new Game(flash.Lib.current);
		inst.init();
		Key.init();
	}
	
}