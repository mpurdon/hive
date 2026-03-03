Code.require_file("test/support/mocks.ex")
Code.require_file("test/support/store_helper.ex")

# Ensure homebrew git is preferred over Xcode git (which may need license acceptance)
brew_bin = "/opt/homebrew/bin"
if File.exists?(Path.join(brew_bin, "git")) do
  path = System.get_env("PATH", "")
  unless String.starts_with?(path, brew_bin) do
    System.put_env("PATH", "#{brew_bin}:#{path}")
  end
end

ExUnit.start()
