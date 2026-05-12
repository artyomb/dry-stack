# frozen_string_literal: true

require "open3"

describe "rparallel" do
  let(:bin) { File.expand_path("../bin/rparallel", __dir__) }

  def run_rparallel(input, *args, env: {})
    Open3.capture3({ "NO_COLOR" => nil, "RPARALLEL_NO_COLOR" => nil }.merge(env), bin, *args, stdin_data: input)
  end

  def strip_ansi(value)
    value.gsub(/\e\[[\d;]+m/, "")
  end

  it "runs stdin lines as tasks and prints a report" do
    stdout, stderr, status = run_rparallel("echo first\necho second\n")
    plain_stdout = strip_ansi(stdout)

    expect(status).to be_success
    expect(stderr).to eq("")
    expect(stdout).to include("[Job 1] first\n")
    expect(stdout).to include("[Job 2] second\n")
    expect(stdout).to include("\e[1mrparallel report\e[0m")
    expect(stdout).to include("\e[32mok")
    expect(plain_stdout).to include("rparallel report")
    expect(plain_stdout).to match(/^\+-+\+-+\+-+\+-+\+-+\+$/)
    expect(plain_stdout).to match(/^\| # \| status \| exit \| duration \| command\s+\|$/)
    expect(plain_stdout).to match(/^\| 1 \| ok\s+\| 0\s+\| \d+\.\d{3}s\s+\| echo first\s+\|$/)
    expect(plain_stdout).to match(/^\| 2 \| ok\s+\| 0\s+\| \d+\.\d{3}s\s+\| echo second \|$/)
  end

  it "ignores blank lines" do
    stdout, = run_rparallel("\n  \necho only\n\n")
    plain_stdout = strip_ansi(stdout)

    expect(plain_stdout).to match(/^\| 1 \| ok\s+\| 0\s+\| \d+\.\d{3}s\s+\| echo only \|$/)
    expect(plain_stdout).not_to match(/^\| 2 \|/)
  end

  it "executes tasks through the shell" do
    stdout, stderr, status = run_rparallel("printf hi | tr h H\n")

    expect(status).to be_success
    expect(stderr).to eq("")
    expect(stdout).to include("[Job 1] Hi\n")
  end

  it "prefixes stderr output with the job number" do
    _stdout, stderr, status = run_rparallel("echo Error >&2\n")

    expect(status).to be_success
    expect(stderr).to eq("\e[31m[Job 1] Error\e[0m\n")
  end

  it "can disable colors for stderr output" do
    _stdout, stderr, status = run_rparallel("echo Error >&2\n", env: { "NO_COLOR" => "1" })

    expect(status).to be_success
    expect(stderr).to eq("[Job 1] Error\n")
  end

  it "runs tasks concurrently" do
    input = "sleep 0.4; echo one\nsleep 0.4; echo two\n"

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    _stdout, _stderr, status = run_rparallel(input)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    expect(status).to be_success
    expect(duration).to be < 0.75
  end

  it "returns a failure when any task fails" do
    stdout, _stderr, status = run_rparallel("echo ok\nfalse\n")
    plain_stdout = strip_ansi(stdout)

    expect(status.exitstatus).to eq(1)
    expect(stdout).to include("[Job 1] ok\n")
    expect(stdout).to include("\e[31mfailed")
    expect(plain_stdout).to match(/^\| 1 \| ok\s+\| 0\s+\| \d+\.\d{3}s\s+\| echo ok \|$/)
    expect(plain_stdout).to match(/^\| 2 \| failed \| 1\s+\| \d+\.\d{3}s\s+\| false\s+\|$/)
  end

  it "rejects unsupported arguments" do
    _stdout, stderr, status = run_rparallel("", "--tag")

    expect(status.exitstatus).to eq(2)
    expect(stderr).to include("Unsupported arguments: --tag")
  end
end
