String shortId(String id, {int length = 6}) {
  if (id.isEmpty) {
    return '';
  }
  if (length <= 0) {
    return '';
  }
  return id.length <= length ? id : id.substring(0, length);
}
