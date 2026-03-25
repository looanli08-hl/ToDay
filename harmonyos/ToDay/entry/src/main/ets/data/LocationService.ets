export class LocationService {
  async getPermissionStatus(): Promise<string> {
    return '未接入';
  }

  async getCurrentCity(): Promise<string> {
    return '上海';
  }
}
