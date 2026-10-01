import { useEffect, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { deliveriesApi } from '../api/resources';

const BASE_TITLE = 'Hssan Delivery Admin';
const SOUND_KEY = 'dispatch-sound';

/** The dispatch queue, refreshed every 15 s even in a background tab. */
export function useWaitingDeliveries() {
  return useQuery({
    queryKey: ['deliveries', 'waiting'],
    queryFn: deliveriesApi.waiting,
    refetchInterval: 15_000,
    refetchIntervalInBackground: true,
  });
}

function readSoundSetting(): boolean {
  try {
    return localStorage.getItem(SOUND_KEY) !== 'off';
  } catch {
    return true;
  }
}

/** Whether new orders chime, remembered per browser. */
export function useDispatchSound(): [boolean, () => void] {
  const [on, setOn] = useState(readSoundSetting);
  const toggle = () => {
    setOn((was) => {
      try {
        localStorage.setItem(SOUND_KEY, was ? 'off' : 'on');
      } catch {
        // Private mode: the setting lasts for this visit only.
      }
      return !was;
    });
  };
  return [on, toggle];
}

/** Two short rising notes, made with Web Audio so no file is needed. */
function chime() {
  try {
    const ctx = new AudioContext();
    [880, 1175].forEach((frequency, i) => {
      const start = ctx.currentTime + i * 0.18;
      const oscillator = ctx.createOscillator();
      const gain = ctx.createGain();
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(0.0001, start);
      gain.gain.exponentialRampToValueAtTime(0.25, start + 0.02);
      gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.35);
      oscillator.connect(gain).connect(ctx.destination);
      oscillator.start(start);
      oscillator.stop(start + 0.4);
    });
    setTimeout(() => ctx.close(), 1000);
  } catch {
    // No audio available: the badge and the tab title still show it.
  }
}

/**
 * Keeps the admin told about orders waiting for a courier, whatever page
 * is open: the count in the tab title, and a chime when a new one comes
 * in (not for the ones already there when the page loaded).
 */
export function useDispatchAlert(soundOn: boolean): number {
  const { data } = useWaitingDeliveries();
  const seen = useRef<Set<number> | null>(null);
  const count = data?.length ?? 0;

  useEffect(() => {
    if (!data) return;
    const ids = data.map((d) => d.id);
    if (seen.current !== null && soundOn && ids.some((id) => !seen.current!.has(id))) {
      chime();
    }
    seen.current = new Set([...(seen.current ?? []), ...ids]);
  }, [data, soundOn]);

  useEffect(() => {
    document.title = count > 0 ? `(${count}) ${BASE_TITLE}` : BASE_TITLE;
    return () => {
      document.title = BASE_TITLE;
    };
  }, [count]);

  return count;
}
