
////////////////////// SYSTEM

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

s.waitForBoot({

    ////////////////////// CONFIGURATION

    var win, genNames, outNames, instances, settings;
    var genMenus, outMenus, freqNums, freqSliders;
    var ampNums, ampSliders, toggles;
    var presets, presetPath, presetMenu, saveButton, loadButton;
    var makeInstance, rowHeight;

    genNames = [
        "0 SinOsc", "1 LFSaw", "2 LatoocarfianC", "3 Gendy3",
        "4 HenonC", "5 LFNoise0", "6 LFNoise1", "7 LFNoise2",
        "8 Dust", "9 Crackle", "10 LorenzL", "11 GbmanL",
        "12 StandardL", "13 CuspL", "14 FBSineC", "15 LinCongC"
    ];

    outNames = Array.fill(16, { |i| "Output " ++ i });

    ////////////////////// CV SYNTH

    SynthDef(\es3CV, {
        |out = 0, type = 0, freq = 1, amp = 0.5, enabled = 1|

        var f, mod;

        f = freq.clip(0.01, 15);

        mod = Select.ar(type.clip(0, 15), [

            SinOsc.ar(f),

            LFSaw.ar(f),

            LatoocarfianC.ar(
                f,
                LFNoise2.kr(2, 1.5, 1.5),
                LFNoise2.kr(2, 1.5, 1.5),
                LFNoise2.kr(2, 0.5, 1.5),
                LFNoise2.kr(2, 0.5, 1.5)
            ).tanh,

            Gendy3.ar(6, 4, 0.3, 0.5, f),

            HenonC.ar(
                f,
                LFNoise2.kr(1, 0.2, 1.2),
                LFNoise2.kr(1, 0.15, 0.15)
            ).tanh,

            LFNoise0.ar(f) * 0.5,
            LFNoise1.ar(f) * 0.5,
            LFNoise2.ar(f) * 0.5,

            Dust.ar(f) * 2 - 1,

            Crackle.ar(
                1.5 + (f * 0.003).clip(0, 0.5)
            ).tanh,

            LeakDC.ar(
                LorenzL.ar(10, 28, 2.667, 0.05, 0.1, 0, 0)
            ).tanh,

            LeakDC.ar(
                GbmanL.ar(f, 1.2, 2.1) * 0.1
            ).tanh,

            LeakDC.ar(
                StandardL.ar(
                    f,
                    LFNoise2.kr(0.5, 0.5, 1.5),
                    0.5,
                    0
                )
            ).tanh,

            CuspL.ar(
                f,
                LFNoise2.kr(0.3, 0.3, 1.0),
                1.9,
                0
            ) * 2 - 1,

            LeakDC.ar(
                FBSineC.ar(f, 1, 0.1, 1.1, 0.5, 0.1, 0.1)
            ).tanh,

            LinCongC.ar(f, 1.1, 0.13, 1.0, 0) * 2 - 1
        ]);

        mod = mod.clip(-1, 1);

        Out.ar(
            out,
            mod * amp.clip(0, 1) * enabled.clip(0, 1)
        );

    }).add;

    s.sync;

    ////////////////////// PRESET BANK

    presetPath = Platform.userAppSupportDir
        +/+ "es3_cv_presets.json";

    presets = Array.fill(16, { nil });

    if(File.exists(presetPath)) {
        try {
            presets = JSON.parse(
                File.readAllString(presetPath)
            ).asArray;

            if(presets.size != 16) {
                Error("Preset bank must contain 16 slots").throw;
            };

            ("Loaded presets from: " ++ presetPath).postln;

        } { |error|
            "Could not load preset bank. Starting with empty slots.".warn;
            presets = Array.fill(16, { nil });
        };
    } {
        ("New preset bank: " ++ presetPath).postln;
    };

    ////////////////////// STATE ARRAYS

    instances = Array.newClear(8);
    settings = Array.newClear(8);

    genMenus = Array.newClear(8);
    outMenus = Array.newClear(8);
    freqNums = Array.newClear(8);
    freqSliders = Array.newClear(8);
    ampNums = Array.newClear(8);
    ampSliders = Array.newClear(8);
    toggles = Array.newClear(8);

    rowHeight = 82;

    ////////////////////// WINDOW

    win = Window(
        "MODULAR CV GENERATOR",
        Rect(100, 60, 850, 790),
        scroll: true
    );

    win.background = Color(0.12, 0.12, 0.14);

    StaticText(win, Rect(15, 10, 820, 25))
        .string_("MODULAR CV GENERATOR / 8 INSTANCES / 16 OUTPUTS")
        .stringColor_(Color.white)
        .font_(Font("Monaco", 13));

    ////////////////////// PRESET CONTROLS

    StaticText(win, Rect(15, 39, 65, 22))
        .string_("PRESET")
        .stringColor_(Color.white)
        .font_(Font("Monaco", 11));

    presetMenu = PopUpMenu(win, Rect(80, 37, 160, 25));
    presetMenu.items = Array.fill(16, { |i|
        "Preset " ++ (i + 1).asString
    });
    presetMenu.value = 0;

    saveButton = Button(win, Rect(250, 37, 85, 25));
    saveButton.states = [
        ["SAVE", Color.white, Color.gray(0.3)]
    ];

    loadButton = Button(win, Rect(345, 37, 85, 25));
    loadButton.states = [
        ["LOAD", Color.white, Color.gray(0.3)]
    ];

    ////////////////////// COLUMN HEADERS

    [
        ["GENERATOR", 15, 100],
        ["OUTPUT BUS", 230, 100],
        ["FREQUENCY (Hz)", 360, 150],
        ["AMPLITUDE", 550, 125],
        ["ON", 750, 50]
    ].do({ |item|
        StaticText(win, Rect(item[1], 75, item[2], 20))
            .string_(item[0])
            .stringColor_(Color.gray(0.75))
            .font_(Font("Monaco", 10));
    });

    ////////////////////// CREATE INSTANCE

    makeInstance = { |index|

        var y, panel, title;
        var genMenu, outMenu;
        var freqSlider, freqNum;
        var ampSlider, ampNum, toggle;
        var synth, updateFreq, updateAmp;

        y = 102 + (index * rowHeight);

        // Default state:
        // [generator, output bus, frequency, amplitude, enabled]

        settings[index] = [0, index, 1.0, 0.5, 0];

        panel = CompositeView(
            win,
            Rect(10, y, 830, 76)
        );

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

        instances[index] = synth;

        // Generator selector

        genMenu = PopUpMenu(panel, Rect(40, 5, 180, 25));
        genMenu.items = genNames;
        genMenu.value = 0;

        genMenu.action = { |menu|
            settings[index][0] = menu.value;
            synth.set(\type, menu.value);
        };

        // Output selector

        outMenu = PopUpMenu(panel, Rect(225, 5, 110, 25));
        outMenu.items = outNames;
        outMenu.value = index;

        outMenu.action = { |menu|
            settings[index][1] = menu.value;
            synth.set(\out, menu.value);
        };

        // Frequency controls

        freqNum = NumberBox(panel, Rect(360, 5, 65, 25));
        freqNum.value = 1;
        freqNum.decimals = 2;
        freqNum.clipLo = 0;
        freqNum.clipHi = 15;

        freqSlider = Slider(panel, Rect(430, 8, 105, 20));
        freqSlider.value = 1 / 15;

        updateFreq = { |value|
            var hz;

            hz = value.clip(0, 15);

            freqNum.value = hz;
            freqSlider.value = hz / 15;

            settings[index][2] = hz;
            synth.set(\freq, hz);
        };

        freqSlider.action = { |sl|
            updateFreq.value(sl.value * 15);
        };

        freqNum.action = { |nb|
            updateFreq.value(nb.value);
        };

        // Amplitude controls

        ampNum = NumberBox(panel, Rect(550, 5, 65, 25));
        ampNum.value = 0.5;
        ampNum.decimals = 3;
        ampNum.clipLo = 0;
        ampNum.clipHi = 1;

        ampSlider = Slider(panel, Rect(620, 8, 105, 20));
        ampSlider.value = 0.5;

        updateAmp = { |value|
            var a;

            a = value.clip(0, 1);

            ampNum.value = a;
            ampSlider.value = a;

            settings[index][3] = a;
            synth.set(\amp, a);
        };

        ampSlider.action = { |sl|
            updateAmp.value(sl.value);
        };

        ampNum.action = { |nb|
            updateAmp.value(nb.value);
        };

        // On/off

        toggle = Button(panel, Rect(750, 5, 65, 27));

        toggle.states = [
            ["OFF", Color.white, Color.gray(0.3)],
            ["ON", Color.white, Color(0.1, 0.45, 0.35)]
        ];

        toggle.value = 0;

        toggle.action = { |button|
            settings[index][4] = button.value;
            synth.set(\enabled, button.value);
        };

        // Store GUI references for preset loading

        genMenus[index] = genMenu;
        outMenus[index] = outMenu;
        freqNums[index] = freqNum;
        freqSliders[index] = freqSlider;
        ampNums[index] = ampNum;
        ampSliders[index] = ampSlider;
        toggles[index] = toggle;
    };

    8.do({ |i|
        makeInstance.value(i);
    });

    ////////////////////// SAVE PRESET

    saveButton.action = {

        var slot, savedSettings;

        slot = presetMenu.value;

        savedSettings = settings.collect({ |state|
            state.copy
        });

        presets[slot] = savedSettings;

        try {
            File.use(presetPath, "w", { |file|
                file.write(JSON.stringify(presets));
            });

            (
                "Saved Preset " ++ (slot + 1)
                ++ " to disk."
            ).postln;

        } { |error|
            "ERROR: Could not save the preset bank.".error;
            error.reportError;
        };
    };

    ////////////////////// LOAD PRESET

    loadButton.action = {

        var slot, data;

        slot = presetMenu.value;
        data = presets[slot];

        if(data.isNil) {

            ("Preset " ++ (slot + 1) ++ " is empty.").postln;

        } {
            if(data.size != 8) {

                "Invalid preset: expected eight instances.".warn;

            } {
                8.do({ |i|

                    var state;

                    state = data[i].asArray;

                    if(state.size == 5) {

                        settings[i] = state.copy;

                        genMenus[i].value = state[0];
                        outMenus[i].value = state[1];

                        freqNums[i].value = state[2];
                        freqSliders[i].value = state[2] / 15;

                        ampNums[i].value = state[3];
                        ampSliders[i].value = state[3];

                        toggles[i].value = state[4];

                        instances[i].set(
                            \type, state[0],
                            \out, state[1],
                            \freq, state[2],
                            \amp, state[3],
                            \enabled, state[4]
                        );

                    } {
                        (
                            "Invalid settings in instance "
                            ++ (i + 1)
                        ).warn;
                    };
                });

                ("Loaded Preset " ++ (slot + 1)).postln;
            };
        };
    };

    ////////////////////// CLEANUP

    win.onClose_({
        instances.do({ |synth|
            if(synth.notNil) {
                synth.free;
            };
        });
    });

    win.front;

});
)
