{ runCommand
, git
, cacert
, python3
, stdenv
}:

{ url
, rev
, sha256
, postFetch ? ""
, postUnpack ? ""
}:
let
  fetched-west-workspace = runCommand "fetched-west-workspace-${rev}"
    {
      nativeBuildInputs = [
        git
        cacert
        python3.pkgs.west
      ];
      outputHash = sha256;
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
    }
    ''
      mkdir -p $out
      west init -m ${url} --mr ${rev} $out
      cd $out
      west update --narrow -o=--depth=1
      for i in $(find . -name '.git')
      do
        rm -rf $i
        echo removing $i for purity!
        echo -e "$(dirname $i)" >> fakeTheseRepos
      done
      sort -o fakeTheseRepos fakeTheseRepos
    '';
in runCommand "fakegit-west-workspace-${rev}" {
  src = fetched-west-workspace;
  nativeBuildInputs = [
    git
    cacert
    python3.pkgs.west
  ];
} ''
  set -eu
  shopt -s dotglob
  unpackPhase
  cd "$sourceRoot"
  ${postUnpack}
  export HOME=$TMP
  # Git is not atomic by default due to auto-gc
  # https://stackoverflow.com/questions/28092485/how-to-prevent-garbage-collection-in-git
  git config --global gc.autodetach false

  # The west commands needs to find .git
  # Remove all .git folders and replace with BS
  # Each of these is done in parallel with & and wait

  function setupFakeGit {
    echo Creating fake dummy git repo in "$1"
    git -C "$1" init
    git -C "$1" config user.email 'foo@example.com'
    git -C "$1" config user.name 'Foo Bar'
    git -C "$1" add -A
    git -C "$1" commit -m 'Fake commit'
    git -C "$1" checkout -b manifest-rev
    git -C "$1" checkout --detach manifest-rev
  }

  setupFakeGit .

  while read -r i
  do
    (
      setupFakeGit "$i"
    ) &
  done < fakeTheseRepos
  wait
  ${postFetch}
  cd -
  mv $sourceRoot $out
''

