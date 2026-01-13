defmodule Mix.Tasks.FetchTypst do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    fetch_typst()
  end

  def fetch_typst() do
    build_dir = Mix.Project.build_path()
    shell = Mix.shell()

    {arch, checksum} = case :os.type() do
      {:unix, :darwin} -> {"aarch64-apple-darwin", "470aa49a2298d20b65c119a10e4ff8808550453e0cb4d85625b89caf0cedf048"}
    end

    typst_path = "#{build_dir}/typst/typst-#{arch}/typst"
    already_have_typst = File.exists?(typst_path)

    if !already_have_typst do
      verify_res = shell.cmd("""
      mkdir typst
      cd typst
      echo '#{checksum}  typst.tar.xz' > typst.tar.xz.sha256
      curl -L https://github.com/typst/typst/releases/download/v0.14.2/typst-#{arch}.tar.xz > typst.tar.xz
      sha256sum -c typst.tar.xz.sha256
      rm typst.tar.xz.sha256
      """, cd: build_dir)

      if verify_res != 0 do
        shell.info("Failed to fetch or verify Typst download!")
        :error
      else
        res = shell.cmd("""
        cd typst
        tar xf typst.tar.xz
        """, cd: build_dir)
        if res == 0 do
          shell.info("Downloaded typst successfully!")
          typst_path
        else
          shell.info("Failed to unpack typst")
          :error
        end
      end
    else
      typst_path
    end
  end
end

defmodule Mix.Tasks.Compile.Typst do
  use Mix.Task.Compiler

  def run(_args) do
    case Mix.Tasks.FetchTypst.fetch_typst() do
      :error -> {:error, []}
      typst_path ->
        shell = Mix.shell()
        build_dir = Mix.Project.build_path()
        res = shell.cmd("""
        pushd "#{build_dir}" > /dev/null
        mkdir artifacts
        popd > /dev/null
        #{typst_path} compile \
          --ignore-system-fonts \
          --font-path deps/fonts \
          main.typ "#{build_dir}/artifacts/main.pdf"
        """, quiet: false)
        if res == 0 do
          shell.info("Wrote #{build_dir}/artifacts/main.pdf")
          :ok
        else
          {:error, []}
        end
    end
  end
end

defmodule MisusingMix.MixProject do
  use Mix.Project

  def project do
    [
      app: :misusing_mix,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: false,
      deps: deps(),
      compilers: [:typst]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:fonts,
        git: "https://github.com/google/fonts",
        ref: "9c5708e735fc805514913d46d259945a3b6ba67a",
        depth: 1,
        sparse: "ofl/ibmplexserif",
        app: false,
        compile: false}
    ]
  end
end
