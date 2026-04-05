import { createContext, useContext } from 'react';
import { hzToSlider } from './tones';

export type GameMode = 'solo' | 'daily';
export type Screen = 'home' | 'memorize' | 'recreate' | 'results';

export interface GameState {
  screen: Screen;
  mode: GameMode;
  seed: number;
  tones: number[];          // target Hz values
  guesses: number[];        // player Hz values
  sliders: number[];        // [0..1] slider positions
  currentTone: number;      // which tone is being shown/played in memorize
}

export interface GameActions {
  startSolo: (tones: number[], seed: number) => void;
  startDaily: (tones: number[], seed: number) => void;
  goRecreate: () => void;
  setSlider: (index: number, value: number) => void;
  goResults: () => void;
  goHome: () => void;
  setCurrentTone: (i: number) => void;
}

export const GameContext = createContext<(GameState & GameActions) | null>(null);

export function useGame(): GameState & GameActions {
  const ctx = useContext(GameContext);
  if (!ctx) throw new Error('useGame must be inside GameProvider');
  return ctx;
}

export const INITIAL_SLIDER = hzToSlider(600); // geometric midpoint ~600 Hz
