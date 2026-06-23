from services.indicators import compute_rsi, compute_sma


def test_compute_sma():
    closes = [1.0, 2.0, 3.0, 4.0, 5.0]
    sma = compute_sma(closes, 3)
    assert len(sma) == 3
    assert sma[-1] == (4, 4.0)


def test_compute_rsi_range():
    closes = [float(i) for i in range(1, 30)]
    rsi = compute_rsi(closes, period=14)
    assert rsi
    _, value = rsi[-1]
    assert 0 <= value <= 100
