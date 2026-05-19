<?php

namespace Tests\Feature;

use Tests\TestCase;

class ExampleTest extends TestCase
{
    /**
     * Root URL redirects to the OTP verification form.
     */
    public function test_root_redirects_to_otp_verify_form(): void
    {
        $response = $this->get('/');

        $response->assertRedirect(route('otp.verify.form'));
    }
}
