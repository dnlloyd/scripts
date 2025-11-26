TEST_KITCHEN="1"; export TEST_KITCHEN
BUSSER_ROOT="/tmp/verifier"; export BUSSER_ROOT
GEM_HOME="/tmp/verifier/gems"; export GEM_HOME
GEM_PATH="/tmp/verifier/gems"; export GEM_PATH
GEM_CACHE="/tmp/verifier/gems/cache"; export GEM_CACHE
ruby="/opt/chef/embedded/bin/ruby"
gem="/opt/chef/embedded/bin/gem"
version="busser"
gem_install_args="busser --no-document --no-format-executable -n /tmp/verifier/bin --no-user-install"
busser="sudo -E /tmp/verifier/bin/busser"
plugins="busser-serverspec"

$gem list --no-versions | grep--no-versions | grep "^busser" 2>&1 >/dev/null
if test $? -ne 0; then
  echo "-----> Installing Busser ($version)"
  $gem install $gem_install_args
else
  echo "-----> Busser installation detected ($version)"
fi

if test ! -f "$BUSSER_ROOT/bin/busser"; then
  $busser setup
fi

for plugin in $plugins; do
  $gem list --no-versions | grep "^$plugin$" 2>&1 >/dev/null
  if test $? -ne 0; then
    echo "-----> Installing Busser plugin: $plugin"
    $busser plugin install $plugin
  else
    echo "-----> Busser plugin detected: $plugin"
  fi
done
