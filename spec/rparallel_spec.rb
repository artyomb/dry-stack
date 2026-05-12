# frozen_string_literal: true

require "open3"

describe "rparallel" do
  let(:bin) { File.expand_path("../bin/rparallel", __dir__) }
  def run_rparallel(input, *args)
    Open3.capture3(bin, *args, stdin_data: input)
  end

  it "runs stdin lines as tasks and prints a report" do
    stdout, stderr, status = run_rparallel("echo first\necho second\n")

    expect(status).to be_success
    expect(stderr).to eq("")
    expect(stdout).to include("first\n")
    expect(stdout).to include("second\n")
    expect(stdout).to include("rparallel report")
    expect(stdout).to match(/^#  status  exit  duration  command$/)
    expect(stdout).to match(/^1  ok\s+0\s+\d+\.\d{3}s\s+echo first$/)
    expect(stdout).to match(/^2  ok\s+0\s+\d+\.\d{3}s\s+echo second$/)
  end

  it "ignores blank lines" do
    stdout, = run_rparallel("\n  \necho only\n\n")

    expect(stdout).to match(/^1  ok\s+0\s+\d+\.\d{3}s\s+echo only$/)
    expect(stdout).not_to match(/^2\s/)
  end

  it "executes tasks through the shell" do
    stdout, stderr, status = run_rparallel("printf hi | tr h H\n")

    expect(status).to be_success
    expect(stderr).to eq("")
    expect(stdout).to include("Hi")
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

    expect(status.exitstatus).to eq(1)
    expect(stdout).to match(/^1  ok\s+0\s+\d+\.\d{3}s\s+echo ok$/)
    expect(stdout).to match(/^2  failed\s+1\s+\d+\.\d{3}s\s+false$/)
  end

  it "rejects unsupported arguments" do
    _stdout, stderr, status = run_rparallel("", "--tag")

    expect(status.exitstatus).to eq(2)
    expect(stderr).to include("Unsupported arguments: --tag")
  end
end
