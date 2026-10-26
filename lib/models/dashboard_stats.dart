class DashboardStats {
  final Map<String, dynamic> rawStats;

  DashboardStats(this.rawStats);

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(json);
  }

  // Example helper getters
  double get totalBusinessGiven => (rawStats['business_given'] ?? 0).toDouble();
  double get totalBusinessReceived => (rawStats['business_received'] ?? 0).toDouble();
  int get referralsGiven => rawStats['referrals_given'] ?? 0;
  int get referralsReceived => rawStats['referrals_received'] ?? 0;
  int get visitorsInvited => rawStats['visitors_invited'] ?? 0;
}
