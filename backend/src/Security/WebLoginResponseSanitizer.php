<?php

namespace App\Security;

use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Security\Core\Authentication\Token\TokenInterface;
use Symfony\Component\Security\Http\Authentication\AuthenticationSuccessHandlerInterface;

/**
 * The admin dashboard's session was moved off localStorage to an httpOnly
 * cookie specifically so an XSS on the page can't read the JWT (see
 * lexik_jwt_authentication.yaml). But that config keeps `token` in the login
 * response body too — mobile authenticates via the Authorization header and
 * never reads the cookie, so it still needs the body. Since both clients
 * share POST /api/auth/login, the admin dashboard's login response still
 * carried the plaintext token: the cookie migration stopped a dormant XSS
 * from lifting it out of storage later, but not a script active in the page
 * at the exact moment of login from reading it straight off the response.
 *
 * The admin dashboard sends X-Client-Platform: web on every request (see
 * admin/src/api/client.ts). When that header is present, strip `token` from
 * the login response body entirely — the cookie this same response sets is
 * all a browser client needs. Mobile never sends the header, so its body
 * token is untouched.
 *
 * This is wired as security.yaml's json_login success_handler directly
 * (not as a service decorator of Lexik's own handler): Symfony's
 * AbstractFactory::createAuthenticationSuccessHandler wraps a configured
 * success_handler in a ChildDefinition, which clones the target service
 * rather than resolving it through the container's normal alias/decoration
 * graph — a #[AsDecorator] on Lexik's handler service silently never runs
 * for firewall-configured handlers. Taking Lexik's real handler as a plain
 * constructor dependency instead sidesteps that entirely.
 */
final class WebLoginResponseSanitizer implements AuthenticationSuccessHandlerInterface
{
    public function __construct(
        #[Autowire(service: 'lexik_jwt_authentication.handler.authentication_success')]
        private readonly AuthenticationSuccessHandlerInterface $inner,
    ) {
    }

    public function onAuthenticationSuccess(Request $request, TokenInterface $token): Response
    {
        $response = $this->inner->onAuthenticationSuccess($request, $token);

        if (!$response instanceof JsonResponse || 'web' !== $request->headers->get('X-Client-Platform')) {
            return $response;
        }

        $data = json_decode($response->getContent(), true) ?? [];
        unset($data['token']);

        // Mirrors Lexik's own AuthenticationSuccessHandler convention for an
        // empty body (see remove_token_from_body_when_cookies_used) — an
        // empty PHP array would otherwise encode as JSON `[]`, not `{}`.
        if ([] === $data) {
            $response->setStatusCode(Response::HTTP_NO_CONTENT);
            $response->setData(null);

            return $response;
        }

        $response->setData($data);

        return $response;
    }
}
