<?php

namespace Tests\Feature;

use Tests\TestCase;

class ExampleTest extends TestCase
{
    /**
     * Root URL redirects to the testbed hub.
     */
    public function test_root_redirects_to_testbed_hub(): void
    {
        $response = $this->get('/');

        $response->assertRedirect(route('testbed.hub'));
    }
}
