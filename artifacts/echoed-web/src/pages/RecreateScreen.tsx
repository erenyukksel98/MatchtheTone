import { useCallback } from 'react';
import { useGame } from '../lib/gameState';
import { TONE_COLORS, sliderToHz, hzToSlider } from '../lib/tones';
import { playTone, previewHz } from '../lib/audio';

const MIN_HZ = 200;
const MAX_HZ = 1800;

export default function RecreateScreen() {
  const { tones, sliders, setSlider, guesses, goResults } = useGame();

  const handleSliderChange = useCallback((index: number, rawValue: number) => {
    setSlider(index, rawValue);
    const hz = sliderToHz(rawValue);
    previewHz(hz);
  }, [setSlider]);

  const handlePreview = useCallback((index: number) => {
    const hz = sliderToHz(sliders[index]);
    playTone(hz, 900, 0.4);
  }, [sliders]);

  return (
    <div className="min-h-screen flex flex-col px-5 py-8" style={{ background: 'var(--bg)' }}>
      {/* Header */}
      <div className="mb-6 fade-up">
        <p className="text-xs font-semibold tracking-widest uppercase text-muted mb-1">Step 2 of 2</p>
        <h2 className="text-2xl font-bold" style={{ color: 'var(--text)' }}>Recreate the Tones</h2>
        <p className="text-sm text-muted mt-1">Drag each slider to match what you heard</p>
      </div>

      {/* Sliders */}
      <div className="flex flex-col gap-4 flex-1">
        {tones.map((_, i) => {
          const color = TONE_COLORS[i];
          const sliderVal = sliders[i] ?? hzToSlider(600);
          const hz = sliderToHz(sliderVal);

          return (
            <div
              key={i}
              className="rounded-2xl p-4 fade-up"
              style={{
                animationDelay: `${i * 0.07}s`,
                background: 'var(--surface)',
                border: `1.5px solid var(--border)`,
              }}
            >
              <div className="flex items-center justify-between mb-3">
                <div className="flex items-center gap-3">
                  <div
                    className="w-8 h-8 rounded-full flex items-center justify-center font-mono font-bold text-sm"
                    style={{ background: `${color}20`, border: `1.5px solid ${color}66`, color }}
                  >
                    {i + 1}
                  </div>
                  <span className="font-mono font-bold text-xl" style={{ color }}>
                    {hz} Hz
                  </span>
                </div>

                <button
                  onClick={() => handlePreview(i)}
                  className="px-3 py-1.5 rounded-xl text-xs font-semibold transition-all"
                  style={{
                    background: `${color}15`,
                    border: `1px solid ${color}44`,
                    color,
                  }}
                >
                  ▶ Preview
                </button>
              </div>

              {/* Logarithmic slider */}
              <div className="relative">
                <input
                  type="range"
                  min={0}
                  max={1000}
                  value={Math.round(sliderVal * 1000)}
                  onChange={e => handleSliderChange(i, Number(e.target.value) / 1000)}
                  className="w-full"
                  style={{
                    WebkitAppearance: 'none',
                    appearance: 'none',
                    height: '6px',
                    borderRadius: '3px',
                    outline: 'none',
                    cursor: 'pointer',
                    background: `linear-gradient(to right, ${color} 0%, ${color} ${sliderVal * 100}%, var(--border) ${sliderVal * 100}%, var(--border) 100%)`,
                  }}
                />
              </div>

              <div className="flex justify-between text-xs text-muted mt-1">
                <span>{MIN_HZ} Hz</span>
                <span>{MAX_HZ} Hz</span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Submit */}
      <div className="mt-6 fade-up" style={{ animationDelay: '0.5s' }}>
        <button
          onClick={goResults}
          className="w-full py-4 rounded-2xl font-semibold text-base transition-all duration-200"
          style={{
            background: 'linear-gradient(135deg, rgba(255,0,255,0.2), rgba(255,0,255,0.06))',
            border: '1.5px solid rgba(255,0,255,0.6)',
            color: '#FF00FF',
            boxShadow: '0 0 18px rgba(255,0,255,0.2)',
          }}
        >
          Submit My Guesses →
        </button>
      </div>

      <style>{`
        input[type=range]::-webkit-slider-thumb {
          -webkit-appearance: none;
          width: 20px;
          height: 20px;
          border-radius: 50%;
          background: #fff;
          cursor: pointer;
          box-shadow: 0 0 6px rgba(0,0,0,0.4);
        }
        input[type=range]::-moz-range-thumb {
          width: 20px;
          height: 20px;
          border-radius: 50%;
          background: #fff;
          cursor: pointer;
          border: none;
        }
      `}</style>
    </div>
  );
}
