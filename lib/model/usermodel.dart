class UserModel {
  String id;
  String name;
  int age;
  String gender;
  String phone;
  String occupation;
  String place;
  String email;

  UserModel({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.phone,
    required this.occupation,
    required this.place,
    required this.email,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "name": name,
      "age": age,
      "gender": gender,
      "phone": phone,
      "occupation": occupation,
      "place": place,
      "email": email,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map["id"]?.toString() ?? map["uid"]?.toString() ?? "",
      name: map["name"]?.toString() ?? map["username"]?.toString() ?? "",
      age: int.tryParse(map["age"]?.toString() ?? "") ?? 0,
      phone: map["phone"]?.toString() ?? "",
      gender: map["gender"]?.toString() ?? "",
      occupation: map["occupation"]?.toString() ?? "",
      place: map["place"]?.toString() ?? "",
      email: map["email"]?.toString() ?? "",
    );
  }
}