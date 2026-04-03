extension OptionalLet<T> on T? {
  void let(void Function(T) block) {
    if (this != null) block(this as T);
  }
}

