# EventBridge_tf_POC
Event bridge is one of the best ways to implement an asynchronous messaging pattern for a cloud system. Its a serverless services that delivers not only a loose-coupled architecture, but also enables:

- Isolation to the components involved;
- Makes it easy to extend or replace services;
- Enables a zero-waste architecture;

The purpose of this demo is to configure API webhooks in eventbridge  via API calls and trigger events through ALB. Event bridge is being used as integration layer to configure API connections and its destinations (webhooks). Further enhancements to API  calls are required to create some gaurdrails around authorization and authentication on the API calls to update connections. 

<img width="1067" alt="image" src="https://user-images.githubusercontent.com/11863956/229814029-7053dea0-c72b-46b3-8583-957787b94b1a.png">

TODO :
Future POC should be enhanced to include websocket connections instead of http from ALB. 
