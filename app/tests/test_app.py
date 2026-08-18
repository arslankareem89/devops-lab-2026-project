import app as application


def test_home():
    client = application.app.test_client()
    response = client.get("/")
    assert response.status_code == 200


def test_health():
    client = application.app.test_client()
    response = client.get("/health")
    assert response.status_code == 200
    assert response.data == b"OK"
