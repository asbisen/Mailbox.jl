module Mailbox

abstract type AbstractMailbox end
abstract type AbstractMail end
export AbstractMailbox, AbstractMail

include("mbox.jl")
export MBox,
    generate_toc,
    get_message

include("email.jl")
export MultipartMail,
    Mail,
    parse_mail

include("utils.jl")
export split_headers_and_body

include("Experimental/Experimental.jl")

end # module Mailbox
