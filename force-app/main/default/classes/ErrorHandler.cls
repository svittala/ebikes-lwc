public with sharing class ErrorHandler {
    public class HandledException extends Exception {
    }

    public static String handle(Exception e) {
        return handle(e, null, null);
    }

    public static String handle(Exception e, String userMessage) {
        return handle(e, userMessage, null);
    }

    public static String handle(
        Exception e,
        String userMessage,
        Map<String, Object> context
    ) {
        if (e == null) {
            return 'An unexpected error occurred.';
        }
        Exception root = getRootCause(e);
        String safeMsg = String.isBlank(userMessage)
            ? getSafeMessage(root)
            : userMessage;

        // Publish platform event
        publishLog(root, safeMsg, context);

        // Return safe message for UI
        return safeMsg;
    }

    public static void raise(Exception e) {
        raise(e, null, null);
    }

    public static void raise(Exception e, String userMessage) {
        raise(e, userMessage, null);
    }

    public static void raise(
        Exception e,
        String userMessage,
        Map<String, Object> context
    ) {
        String safe = handle(e, userMessage, context);
        // AuraHandledException is best for surfacing to Aura/LWC via @AuraEnabled
        AuraHandledException ahe = new AuraHandledException(safe);
        ahe.setMessage(safe);
        throw ahe;
    }

    public static Exception getRootCause(Exception e) {
        Exception current = e;
        // Apex does not expose generic cause() on all exceptions, but many standard exceptions surface nested messages in getMessage()
        // We still return the original if we cannot traverse further.
        return current == null ? null : current;
    }

    public static String getSafeMessage(Exception e) {
        if (e == null)
            return 'An unexpected error occurred.';
        // Avoid leaking SOQL, field names, or internal details
        String msg = e.getMessage();
        if (String.isBlank(msg))
            return 'An unexpected error occurred.';
        // Trim overly long messages
        if (msg.length() > 255) {
            msg = msg.substring(0, 252) + '...';
        }
        return msg;
    }

    public static String toStacktrace(Exception e) {
        if (e == null)
            return null;
        // Apex lacks a full stacktrace API; include message and line data where available.
        List<String> parts = new List<String>();
        parts.add('Message=' + safeString(e.getMessage()));
        Integer lineNumber;
        String className;
        String methodName;
        try {
            lineNumber = e.getLineNumber();
        } catch (Exception ignore) {
        }
        try {
            className = e.getTypeName();
        } catch (Exception ignore) {
        }
        try {
            methodName = e.getCause() == null
                ? null
                : e.getCause().getMessage();
        } catch (Exception ignore) {
        }
        if (className != null)
            parts.add('Class=' + className);
        if (methodName != null)
            parts.add('Method=' + methodName);
        if (lineNumber != null)
            parts.add('Line=' + String.valueOf(lineNumber));
        return String.join(parts, ' | ');
    }

    public static Map<String, Object> toContext(
        Exception e,
        Map<String, Object> extra
    ) {
        Map<String, Object> ctx = new Map<String, Object>();
        if (extra != null)
            ctx.putAll(extra);
        try {
            ctx.put('UserId', UserInfo.getUserId());
        } catch (Exception ignore) {
        }
        try {
            ctx.put('OrgId', UserInfo.getOrganizationId());
        } catch (Exception ignore) {
        }
        try {
            ctx.put('Username', UserInfo.getUserName());
        } catch (Exception ignore) {
        }
        // try { ctx.put('TxId', safeString(getTxId())); } catch (Exception ignore) {}
        if (e != null) {
            try {
                ctx.put('ExceptionType', e.getTypeName());
            } catch (Exception ignore) {
            }
            try {
                ctx.put('LineNumber', e.getLineNumber());
            } catch (Exception ignore) {
            }
        }
        return ctx;
    }

    public static Error_Log__e publishLog(
        Exception e,
        String userMessage,
        Map<String, Object> context
    ) {
        if (e == null && String.isBlank(userMessage))
            return null;

        Exception root = getRootCause(e);
        String exceptionType;
        Integer lineNumber;
        String className;
        try {
            exceptionType = root == null ? null : root.getTypeName();
        } catch (Exception ignore) {
        }
        try {
            lineNumber = root == null ? null : root.getLineNumber();
        } catch (Exception ignore) {
        }
        try {
            className = root == null ? null : root.getTypeName();
        } catch (Exception ignore) {
        }

        Map<String, Object> ctx = toContext(root, context);
        String ctxJson;
        try {
            ctxJson = JSON.serialize(ctx);
        } catch (Exception ignore) {
            ctxJson = null;
        }

        Error_Log__e evt = new Error_Log__e();
        evt.Message__c = userMessage != null
            ? userMessage
            : getSafeMessage(root);
        evt.Exception_Type__c = safeString(exceptionType);
        evt.Stacktrace__c = safeString(toStacktrace(root));
        evt.Context__c = safeString(ctxJson);
        evt.Root_Cause__c = safeString(root == null ? null : root.getMessage());
        evt.Caused_By__c = null; // Not reliably available in Apex
        evt.ClassName__c = safeString(className);
        evt.MethodName__c = null; // Not reliably available in Apex
        evt.LineNumber__c = lineNumber;
        evt.UserId__c = safeString(UserInfo.getUserId());
        evt.RecordId__c = safeString(
            (String) (context != null ? context.get('RecordId') : null)
        );
        // evt.TxId__c = safeString(getTxid());

        try {
            EventBus.publish(evt);
        } catch (Exception publishErr) {
            // As a fallback, write to debug but do not rethrow to avoid masking original flow
            System.debug(
                LoggingLevel.ERROR,
                'Failed to publish Error_Log__e: ' + publishErr.getMessage()
            );
        }
        return evt;
    }

    private static String safeString(String s) {
        return s == null ? null : s;
    }
}
