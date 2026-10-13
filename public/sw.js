self.addEventListener('install',event=>{self.skipWaiting();});
self.addEventListener('activate',event=>{event.waitUntil(self.clients.claim());});
self.addEventListener('push',event=>{
 let data={title:'INFOTELCOM Connect',body:'Nouvelle activité dans votre espace de travail.',url:'/'};
 try{if(event.data)data={...data,...event.data.json()};}catch{if(event.data)data.body=event.data.text();}
 event.waitUntil(self.registration.showNotification(data.title||'INFOTELCOM Connect',{
  body:data.body||'Nouvelle activité',icon:'/favicon.ico',badge:'/favicon.ico',
  tag:data.tag||'connect-notification',data:{url:data.url||'/'},renotify:false
 }));
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();
 const target=new URL(event.notification.data?.url||'/',self.location.origin).href;
 event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(clients=>{
  const existing=clients.find(client=>client.url.startsWith(self.location.origin));
  if(existing){existing.navigate(target);return existing.focus();}
  return self.clients.openWindow(target);
 }));
});
