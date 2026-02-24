defmodule Hive.Web.Layout do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Hive Control Plane</title>
        <script src="https://cdn.tailwindcss.com"></script>
        <script src="//unpkg.com/alpinejs" defer></script>
      </head>
      <body class="bg-gray-900 text-gray-100 font-mono antialiased">
        <%= @inner_content %>
      </body>
    </html>
    """
  end
end
