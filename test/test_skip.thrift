struct AllTypes {
  1:  optional bool bool_field
  2:  optional byte byte_field
  3:  optional i16 i16_field
  4:  optional i32 i32_field
  5:  optional i64 i64_field
  6:  optional double double_field
  7:  optional string string_field
  // 8:  optional list<i32> int_list
  // 9:  optional set<string> string_set
  // 10: optional map<string,i32> string_int_map
  11: optional byte final_field
}

struct Integers {
  1:  i32 int_field
  2:  list<i32> int_list
  3:  set<i32>  int_set
}

struct Container {
  1:  i32 first_field
  // 2:  Integers second_struct
  3:  i32 third_field
}

exception SimpleException {
  1:  string message
  2:  i32 line_number
}

exception UnusedException {
  1:  bool unused
}

enum ThrowType {
  NormalReturn = 0
  DeclaredException = 1
  UndeclaredException = 2
  Error = 3
}

service TestSkipService {
  i32 add_one(1: i32 input)

  i32 sum_ints(1: Container ints, 2: i32 second)

  AllTypes echo(1: AllTypes all_types)

  i32 throw_exception(1: byte throw_type)
    throws (1: SimpleException e, 2: UnusedException ue)

  oneway void cast(1: string message)
}

// Local Variables:
// indent-tabs-mode: nil
// comment-start: "// "
// End:
