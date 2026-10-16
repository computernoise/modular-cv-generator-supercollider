////////////////////// System
(
s = Server.local;
s.options.outDevice_("Babyface Pro (72994168)");
s.options.numOutputBusChannels_(16);
s.options.inDevice_("Babyface Pro (72994168)");
s.options.numInputBusChannels_(8);
s.options.sampleRate_(96000);
s.options.blockSize = 64;
s.options.numBuffers = 1024 * 16;
s.options.memSize = 8192 * 128;
s.freeAll;
s.waitForBoot({

////////////////////// MODULAR CV GENERATOR
////////////////////// 8 independent instances / 16 generators
////////////////////// Output buses: 0–15
////////////////////// Frequency: 0–15 Hz / Amplitude: 0–1

	var win, genNames, outNames, instances;
	var makeInstance, header, rowHeight;

	genNames = [
		"0 SinOsc", "1 LFSaw", "2 LatoocarfianC", "3 Gendy3",
		"4 HenonC", "5 LFNoise0", "6 LFNoise1", "7 LFNoise2",
		"8 Dust", "9 Crackle", "10 LorenzL", "11 GbmanL",
		"12 StandardL", "13 CuspL", "14 FBSineC", "15 LinCongC"
	];

	outNames = Array.fill(16, { |i| "Output " ++ i });

	SynthDef(\es3CV, {
		|out = 0, type = 0, freq = 1, amp = 0.5, enabled = 1|

		var f, mod;

		f = freq.clip(0.01, 15);

		mod = Select.ar(type.clip(0, 15), [
			SinOsc.ar(f),
			LFSaw.ar(f),

			LatoocarfianC.ar(f,
				LFNoise2.kr(2, 1.5, 1.5),
				LFNoise2.kr(2, 1.5, 1.5),
				LFNoise2.kr(2, 0.5, 1.5),
				LFNoise2.kr(2, 0.5, 1.5)
			).tanh,

			Gendy3.ar(6, 4, 0.3, 0.5, f),

			HenonC.ar(f,
				LFNoise2.kr(1, 0.2, 1.2),
				LFNoise2.kr(1, 0.15, 0.15)
			).tanh,

			// LFNoise: reduced to 50% for additional headroom
			LFNoise0.ar(f) * 0.5,
			LFNoise1.ar(f) * 0.5,
			LFNoise2.ar(f) * 0.5,

			Dust.ar(f) * 2 - 1,
			Crackle.ar(1.5 + (f * 0.003).clip(0, 0.5)).tanh,

			LeakDC.ar(
				LorenzL.ar(10, 28, 2.667, 0.05, 0.1, 0, 0)
			).tanh,

			LeakDC.ar(GbmanL.ar(f, 1.2, 2.1) * 0.1).tanh,

			LeakDC.ar(
				StandardL.ar(f, LFNoise2.kr(0.5, 0.5, 1.5), 0.5, 0)
			).tanh,

			CuspL.ar(f, LFNoise2.kr(0.3, 0.3, 1.0), 1.9, 0) * 2 - 1,

			LeakDC.ar(
				FBSineC.ar(f, 1, 0.1, 1.1, 0.5, 0.1, 0.1)
			).tanh,

			LinCongC.ar(f, 1.1, 0.13, 1.0, 0) * 2 - 1
		]);

		// Final safety limit for all generators
		mod = mod.clip(-1, 1);

		Out.ar(out, mod * amp.clip(0, 1) * enabled.clip(0, 1));

	}).add;

	s.sync;

	instances = Array.newClear(8);
	rowHeight = 82;

	win = Window(
		"MODULAR CV GENERATOR",
		Rect(100, 60, 850, 740),
		scroll: true
	);

	win.background = Color(0.12, 0.12, 0.14);

	header = StaticText(win, Rect(15, 10, 820, 28));
	header.string = "MODULAR CV GENERATOR  /  8 INSTANCES  /  OUTPUT BUS 0–15";
	header.stringColor = Color.white;
	header.font = Font("Monaco", 13);

	[
		["GENERATOR", 15, 100],
		["OUTPUT BUS", 230, 100],
		["FREQUENCY (Hz)", 360, 150],
		["AMPLITUDE", 550, 125],
		["ON", 750, 50]
	].do({ |item|
		var label = StaticText(win, Rect(item[1], 43, item[2], 20));
		label.string = item[0];
		label.stringColor = Color.gray(0.75);
		label.font = Font("Monaco", 10);
	});

	makeInstance = { |index|
		var y, panel, title, genMenu, outMenu;
		var freqSlider, freqNum, ampSlider, ampNum, toggle;
		var synth, updateFreq, updateAmp;

		y = 67 + (index * rowHeight);

		panel = CompositeView(win, Rect(10, y, 830, 76));
		panel.background = Color(0.19, 0.19, 0.22);

		title = StaticText(panel, Rect(8, 5, 25, 22));
		title.string = (index + 1).asString;
		title.stringColor = Color.white;
		title.font = Font("Monaco", 14);

		synth = Synth(\es3CV, [
			\out, index,
			\type, 0,
			\freq, 1,
			\amp, 0.5,
			\enabled, 0
		]);

		genMenu = PopUpMenu(panel, Rect(40, 5, 180, 25));
		genMenu.items = genNames;
		genMenu.value = 0;
		genMenu.action = { |menu|
			synth.set(\type, menu.value);
		};

		outMenu = PopUpMenu(panel, Rect(225, 5, 110, 25));
		outMenu.items = outNames;
		outMenu.value = index;
		outMenu.action = { |menu|
			synth.set(\out, menu.value);
		};

		freqNum = NumberBox(panel, Rect(360, 5, 65, 25));
		freqNum.value = 1;
		freqNum.decimals = 2;
		freqNum.clipLo = 0;
		freqNum.clipHi = 15;

		freqSlider = Slider(panel, Rect(430, 8, 105, 20));
		freqSlider.value = 1 / 15;

		updateFreq = { |value|
			var hz = value.clip(0, 15);
			freqNum.value = hz;
			freqSlider.value = hz / 15;
			synth.set(\freq, hz);
		};

		freqSlider.action = { |sl|
			updateFreq.value(sl.value * 15);
		};

		freqNum.action = { |nb|
			updateFreq.value(nb.value);
		};

		ampNum = NumberBox(panel, Rect(550, 5, 65, 25));
		ampNum.value = 0.5;
		ampNum.decimals = 3;
		ampNum.clipLo = 0;
		ampNum.clipHi = 1;

		ampSlider = Slider(panel, Rect(620, 8, 105, 20));
		ampSlider.value = 0.5;

		updateAmp = { |value|
			var a = value.clip(0, 1);
			ampNum.value = a;
			ampSlider.value = a;
			synth.set(\amp, a);
		};

		ampSlider.action = { |sl|
			updateAmp.value(sl.value);
		};

		ampNum.action = { |nb|
			updateAmp.value(nb.value);
		};

		toggle = Button(panel, Rect(750, 5, 65, 27));
		toggle.states = [
			["OFF", Color.white, Color.gray(0.3)],
			["ON", Color.white, Color(0.1, 0.45, 0.35)]
		];
		toggle.value = 0;
		toggle.action = { |button|
			synth.set(\enabled, button.value);
		};

		instances[index] = synth;
	};

	8.do({ |i| makeInstance.value(i) });

	win.onClose_({
		instances.do({ |synth|
			if(synth.notNil) { synth.free };
		});
	});

	win.front;

});
)

