get_type(::AbstractDerivativeOperator{T}) where {T} = T

function *(A::AbstractDerivativeOperator,x::AbstractVector)
    #=
        We will output a vector which is a supertype of the types of A and x
        to ensure numerical stability
    =#
    get_type(A) != eltype(x) ? error("DiffEqOperator and array are not of same type!") : nothing
    y = zeros(promote_type(eltype(A),eltype(x)), length(x))
    LinearAlgebra.mul!(y, A::AbstractDerivativeOperator, x::AbstractVector)
    return y
end


function *(A::AbstractDerivativeOperator,M::AbstractMatrix)
    #=
        We will output a vector which is a supertype of the types of A and x
        to ensure numerical stability
    =#
    get_type(A) != eltype(M) ? error("DiffEqOperator and array are not of same type!") : nothing
    y = zeros(promote_type(eltype(A),eltype(M)), size(M))
    LinearAlgebra.mul!(y, A::AbstractDerivativeOperator, M::AbstractMatrix)
    return y
end


function *(M::AbstractMatrix,A::AbstractDerivativeOperator)
    #=
        We will output a vector which is a supertype of the types of A and x
        to ensure numerical stability
    =#
    get_type(A) != eltype(M) ? error("DiffEqOperator and array are not of same type!") : nothing
    y = zeros(promote_type(eltype(A),eltype(M)), size(M))
    LinearAlgebra.mul!(y, A::AbstractDerivativeOperator, M::AbstractMatrix)
    return y
end


function *(A::AbstractDerivativeOperator,B::AbstractDerivativeOperator)
    # TODO: it will result in an operator which calculates
    #       the derivative of order A.dorder + B.dorder of
    #       approximation_order = min(approx_A, approx_B)
end


function negate!(arr::T) where T
    if size(arr,2) == 1
        rmul!(arr,-one(eltype(arr[1]))) #fix right neumann bc, eltype(Vector{T}) doesnt work.
    else
        for row in arr
            rmul!(row,-one(eltype(arr[1])))
        end
    end
end


struct DerivativeOperator{T<:Real,S<:SVector} <: AbstractDerivativeOperator{T}
    derivative_order    :: Int
    approximation_order :: Int
    dx                  :: T
    dimension           :: Int
    stencil_length      :: Int
    stencil_coefs       :: S
    boundary_point_count:: Tuple{Int,Int}
    boundary_length     :: Tuple{Int,Int}
    low_boundary_coefs  :: Vector{S}
    high_boundary_coefs :: Vector{S}

    function DerivativeOperator{T,S}(derivative_order::Int,
                                     approximation_order::Int, dx::T,
                                     dimension::Int) where
                                     {T<:Real,S<:SVector}
        dimension            = dimension
        dx                   = dx
        stencil_length       = derivative_order + approximation_order - 1 + (derivative_order+approximation_order)%2
        bl                   = derivative_order + approximation_order
        boundary_length      = (bl,bl)
        bpc                  = stencil_length - div(stencil_length,2) + 1
        bpc_array            = [bpc,bpc]
        grid_step            = one(T)
        low_boundary_coefs   = Vector{S}[]
        high_boundary_coefs  = Vector{S}[]
        stencil_coefs        = convert(SVector{stencil_length, T}, calculate_weights(derivative_order, zero(T),
                               grid_step .* collect(-div(stencil_length,2) : 1 : div(stencil_length,2))))

        new(derivative_order, approximation_order, dx, dimension, stencil_length,
            stencil_coefs,
            boundary_point_count,
            boundary_length,
            low_boundary_coefs,
            high_boundary_coefs
            )
    end
    DerivativeOperator{T}(dorder::Int,aorder::Int,dx::T,dim::Int) where {T<:Real} =
        DerivativeOperator{T, SVector{dorder+aorder-1+(dorder+aorder)%2,T}}(dorder, aorder, dx, dim)
end

#=
    This function is used to update the boundary conditions especially if they evolve with
    time.
=#
function DiffEqBase.update_coefficients!(A::DerivativeOperator{T,S}) where {T<:Real,S<:SVector}
    nothing
end

#################################################################################################

(L::DerivativeOperator)(u,p,t) = L*u
(L::DerivativeOperator)(du,u,p,t) = mul!(du,L,u)

#=
    The Inf opnorm can be calculated easily using the stencil coeffiicents, while other opnorms
    default to compute from the full matrix form.
=#
function LinearAlgebra.opnorm(A::DerivativeOperator{T,S}, p::Real=2) where {T,S}
    if p == Inf && LBC in [:Dirichlet0, :Neumann0, :periodic] && RBC in [:Dirichlet0, :Neumann0, :periodic]
        sum(abs.(A.stencil_coefs)) / A.dx^A.derivative_order
    else
        opnorm(convert(Array,A), p)
    end
end
