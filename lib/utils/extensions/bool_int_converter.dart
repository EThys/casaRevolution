import 'package:flutter/material.dart';


extension IntToBool on dynamic {
  bool? aBool() {
    if (this == null) return null;
    if (this is bool) return this as bool;
    if (this is int) return (this as int) == 1;
    if (this is String) {
      return this == '1' || this.toLowerCase() == 'true';
    }
    return null;
  }
}

extension BoolToInt on bool? {
  int? aInt() {
    if (this == null) return null;
    return this! ? 1 : 0;
  }
}