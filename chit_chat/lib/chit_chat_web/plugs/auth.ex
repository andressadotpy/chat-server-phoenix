defmodule ChitChat.Auth do
  import Plug.Conn
  import Phoenix.Controller
  alias ChitChatWeb.Router.Helpers
  alias ChitChatWeb.ErrorView

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && ChitChat.Accounts.get_user!(user_id)
    put_current_user(conn, user)
  end

  # function to restrict access if the user isn't logged
  # if it's logged in
  def logged_in_user(conn = %{assigns: %{current_user: %{}}}, _), do: conn

  # if it's not logged in, doesn't have a current_user
  def logged_in_user(conn, _opts) do
    conn
    |> put_flash(:error, "You must be logged in to access that page.")
    |> redirect(to: Helpers.page_path(conn, :index))
    |> halt()
  end

  def admin_user(conn = %{assigns: %{admin_user: true}}, _), do: conn

  def admin_user(conn, opts) do
    if opts[:pokerface] do
      conn
      |> put_status(404)
      |> render(ErrorView, :"404", message: "Page not found")
      |> halt()
    end

    conn
    |> put_flash(:error, "You do not have access to that page.")
    |> redirect(to: Helpers.page_path(conn, :index))
    |> halt()
  end

  # admin access
  defp put_current_user(conn, user) do
    conn
    |> assign(:current_user, user)
    |> assign(
      :admin_user,
      !!user && !!user.credential && user.credential.email == "acabistani@gmail.com"
    )
  end
end
