/// Formatuje ilość składnika do czytelnego tekstu, z precyzją dopasowaną
/// do jednostki — zamiast bezwarunkowo zaokrąglać do liczby całkowitej.
///
/// UWAGA (naprawa — błąd "Cebula 0kg"): poprzednio wyświetlanie ilości
/// w kilku miejscach używało `quantity.toStringAsFixed(0)` niezależnie
/// od jednostki. To ma sens dla "sztuk" (2 szt, nie 2.3 szt), ale dla
/// jednostek wagowych/objętościowych (kg, l) UŁAMKOWE wartości są
/// całkowicie normalne — np. 0.15 kg cebuli (mniej niż cała torebka).
/// Zaokrąglanie takiej wartości do 0 miejsc po przecinku dawało "0kg"
/// na ekranie, mimo że w bazie poprawnie zapisana była rozsądna,
/// niezerowa ilość — myląco wyglądające jak błąd, choć dane były OK.
String formatQuantity(double quantity, String unit) {
  // Liczba całkowita (niezależnie od jednostki) — pokaż bez zbędnych
  // miejsc po przecinku, to zawsze czytelniejsze (np. "1 kg", "2 szt").
  if (quantity == quantity.roundToDouble()) {
    return quantity.toStringAsFixed(0);
  }
  // Wartość ułamkowa — pokaż z precyzją, usuwając zbędne końcowe zera
  // (np. "0.15", nie "0.150"; "1.5", nie "1.50").
  String formatted = quantity.toStringAsFixed(2);
  if (formatted.contains('.')) {
    formatted = formatted.replaceFirst(RegExp(r'0+$'), '');
    formatted = formatted.replaceFirst(RegExp(r'\.$'), '');
  }
  return formatted;
}
