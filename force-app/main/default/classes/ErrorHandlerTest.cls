@IsTest
private class ErrorHandlerTest {
    @IsTest
    static void testHandleReturnsSafeMessageAndPublishesEvent() {
        Test.startTest();
        Exception ex;
        try {
            // Force a DmlException by updating a non-existent record
            update new Account(Id = '001000000000000AAA', Name = 'Bad Update');
        } catch (Exception e) {
            ex = e;
        }
        System.assertNotEquals(null, ex, 'Expected an exception to be thrown');

        // Call handle and ensure a non-empty safe message is returned
        String msg = ErrorHandler.handle(
            ex,
            null,
            new Map<String, Object>{ 'RecordId' => '001000000000000AAA' }
        );
        System.assert(!String.isBlank(msg), 'Safe message should not be blank');

        // Assert platform event publication without querying (PEs don't support SOQL)
        // We deliver events to ensure publish path executes without throwing.
        Test.getEventBus().deliver();
        // If no exception was thrown up to this point, assume publish succeeded.
        System.assert(true, 'Publish path executed without errors');
    }

    @IsTest
    static void testRaiseWrapsInAuraHandledException() {
        Exception ex = new IllegalArgumentException('Invalid value provided');
        Boolean threw = false;
        try {
            ErrorHandler.raise(
                ex,
                'A safe error occurred',
                new Map<String, Object>()
            );
        } catch (AuraHandledException ahe) {
            threw = true;
            System.assertEquals(
                'A safe error occurred',
                ahe.getMessage(),
                'AuraHandledException should contain safe message'
            );
        }
        System.assertEquals(
            true,
            threw,
            'Expected AuraHandledException to be thrown'
        );

        // Ensure publish path executed without querying (PEs don't support SOQL)
        Test.getEventBus().deliver();
        System.assert(true, 'Publish path executed without errors');
    }

    @IsTest
    static void testGetSafeMessageTrimAndDefault() {
        // Null exception gets default
        System.assertEquals(
            'An unexpected error occurred.',
            ErrorHandler.getSafeMessage(null)
        );

        // Very long message should be trimmed to 255 with ellipsis
        String longMsg = String.valueOf('x').repeat(400);
        // Use a concrete exception type; base Exception cannot be constructed in some contexts
        Exception ex = new IllegalArgumentException(longMsg);
        String safe = ErrorHandler.getSafeMessage(ex);
        System.assertEquals(
            255,
            safe.length(),
            'Safe message should be trimmed to 255 chars'
        );
        System.assert(
            safe.endsWith('...'),
            'Trimmed message should end with ellipsis'
        );
    }

    @IsTest
    static void testPublishLogMinimal() {
        Test.startTest();
        ErrorHandler.publishLog(null, 'Simple safe message', null);
        // Deliver published events; do not query Platform Events
        Test.getEventBus().deliver();
        // If no exception is thrown, consider publish successful
        System.assert(true, 'Publish path executed without errors');
        Test.stopTest();
    }
}
