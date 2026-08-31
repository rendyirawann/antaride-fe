/// Satu hasil pencarian alamat.
///
/// ============================================================================
///  NAMA DAN ALAMAT DIPISAH, DAN ITU MENENTUKAN BENTUK DAFTAR SARANNYA
/// ============================================================================
///  Geocoder mengembalikan satu kalimat panjang seperti
///
///      "Stasiun Lubuk Pakam, Jalan Stasiun, Lubuk Pakam, Deli Serdang,
///       Sumatera Utara, 20512, Indonesia"
///
///  Menampilkannya utuh dalam satu baris berarti pemotongan "..." jatuh
///  tepat setelah beberapa kata pertama — dan di daftar berisi delapan saran,
///  semuanya terlihat mirip karena yang terbaca hanya bagian yang sama.
///
///  Backend memisahkan [name] (bagian paling spesifik) dari [address] (kalimat
///  lengkap), jadi barisnya bisa bertingkat: nama tebal di atas, alamat kecil
///  satu baris di bawahnya.
/// ============================================================================
class Place {
  const Place({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: (json['name'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',

      // Backend mengirimnya sebagai angka, tapi JSON tidak membedakan int dan
      // double: koordinat yang kebetulan bulat (mis. 3.0) datang sebagai int
      // dan `as double` melempar. `num` menerima keduanya.
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Bagian paling spesifik: nama tempat, atau nama jalan.
  final String name;

  /// Alamat lengkap seperti yang dikembalikan geocoder.
  final String address;

  final double lat;
  final double lng;
}
