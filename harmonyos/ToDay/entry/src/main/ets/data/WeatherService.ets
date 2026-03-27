import { HourlyWeather } from '../model/SharedDataTypes';

export class WeatherService {
  async getPermissionStatus(): Promise<string> {
    return 'Mock';
  }

  async loadHourlyWeather(date: number): Promise<HourlyWeather[]> {
    const dayStart = new Date(date);
    dayStart.setHours(0, 0, 0, 0);
    const base = dayStart.getTime();
    const result: HourlyWeather[] = [];
    for (let hour = 0; hour < 24; hour += 1) {
      result.push({
        date: base + hour * 60 * 60 * 1000,
        temperature: hour < 7 ? 12 : hour < 18 ? 21 : 15,
        condition: hour < 7 ? 'fog' : hour < 18 ? 'clear' : 'cloudy',
        symbolName: hour < 7 ? 'fog' : hour < 18 ? 'sun' : 'cloud'
      });
    }
    return result;
  }
}
