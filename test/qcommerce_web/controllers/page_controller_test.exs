defmodule QcommerceWeb.PageControllerTest do
  use QcommerceWeb.ConnCase
  alias QcommerceWeb.Paths

  test "GET /", %{conn: conn} do
    conn = get(conn, Paths.home())
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end
end
