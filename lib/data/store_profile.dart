class StoreProfile {
  final String id;
  final String name;
  const StoreProfile(this.id, this.name);

  static const bayHai = StoreProfile('bay-hai', 'Bảy Hải');
  static const haiSoc = StoreProfile('hai-soc', 'Hai Sóc');
  static const stores = [haiSoc, bayHai];
  static StoreProfile current = bayHai;
  static Future<void> Function()? chooseAnother;
  String get location => id == bayHai.id ? 'Gò Dầu • Tây Ninh' : '';
  String get address => id == bayHai.id
      ? 'Ấp Bàu Vừng, Xã Phước Trạch, Huyện Gò Dầu, Tỉnh Tây Ninh'
      : '';
  String get phone => id == bayHai.id ? '0343 744 091' : '';

  static String profilesPath(String storeId) =>
      storeId == bayHai.id ? 'users' : 'stores/$storeId/members';
  static String auditPath(String storeId) =>
      storeId == bayHai.id ? 'accountAudit' : 'stores/$storeId/accountAudit';
}
