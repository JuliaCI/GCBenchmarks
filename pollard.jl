function pollardfactor(n::T) where T<:Integer
           for c in T(1):(n - 3)
               G, r, q = ones(T,3)
               y = 2
               m::T = 1900
               ys::T = 0
               x::T = 0
               while G == 1
                   x = y
                   for i in 1:r
                       y = (y^2 + c) % n
                   end
                   k = T(0)
                   G = T(1)
                   while k < r && G == 1
                       for i in 1:min(r - k, m)
                           ys = y
                           y = (y^2 + c) % n
                           q = (q * abs(x - y)) % n
                       end
                       G = gcd(q, n)
                       k += m
                   end
                   r *= 2
               end
               G == n && (G = T(1))
               while G == 1
                   ys = (ys^2 + c) % n
                   G = gcd(abs(x - ys), n)
               end
               if G != n
                   return G
               end
           end
        end
 
 @time pollardfactor(big(1208925819691594988651321))
