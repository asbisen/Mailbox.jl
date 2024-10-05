push!(LOAD_PATH, pwd())
using Test
using Mailbox

@testset "MBox Tests" begin
    # Use the sample mbox file
    test_mbox_path = joinpath("data", "sample.mbox", "mbox")

    @testset "MBox constructor" begin
        mbox = MBox(test_mbox_path)
        @test mbox.path == abspath(test_mbox_path)
        @test isnothing(mbox.toc)
    end

    @testset "generate_toc" begin
        # Test the generation of the table of contents (TOC) for the mbox file
        toc = generate_toc(test_mbox_path)

        # Check if the TOC has entries
        @test !isempty(toc)

        # Ensure that each value in the TOC is a Tuple of two Integers
        # representing the start and end positions of each message
        @test all(x -> x isa Tuple{Int,Int}, values(toc))
    end

    @testset "get_message" begin
        mbox = MBox(test_mbox_path)

        # Test getting the first message
        message = get_message(mbox, 1)
        @test message isa Vector{UInt8}
        @test !isempty(message)

        # Test error for non-existent message
        @test_throws KeyError get_message(mbox, length(mbox) + 1)
    end

    @testset "MBox iteration" begin
        mbox = MBox(test_mbox_path)

        @test length(mbox) > 0
        @test eltype(mbox) == Vector{UInt8}

        messages = collect(mbox)
        @test length(messages) == length(mbox)
        @test all(m -> m isa Vector{UInt8}, messages)

        @test String(mbox[1]) == String(get_message(mbox, 1))
        @test String(mbox[end]) == String(get_message(mbox, length(mbox)))

        @test_throws KeyError mbox[length(mbox) + 1]
    end
end
